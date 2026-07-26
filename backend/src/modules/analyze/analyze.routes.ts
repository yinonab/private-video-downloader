import { FastifyPluginAsync } from "fastify";
import { authDevice } from "../../middleware/authDevice";
import { analyzeBodySchema } from "./analyze.schemas";
import { analyzeUrl } from "./analyze.service";
import { AppError, codes } from "../../types/errors";
import { assertUnderDailyAnalyzeLimit, incrementAnalyzeCount } from "../../services/rateLimit";
import { config } from "../../config";
import { notifyAnalyzeFailedGeneric, safeHostFromUrlString } from "../../services/operationalAlerts";
import { logAnalyzePerf } from "../../services/analyzePerf";

const analyzeRoutes: FastifyPluginAsync = async (app) => {
  app.post("/analyze", { preHandler: authDevice }, async (request, reply) => {
    const parsed = analyzeBodySchema.safeParse(request.body);
    if (!parsed.success) {
      const rawUrl = (request.body as { url?: unknown }).url;
      const urlHost =
        typeof rawUrl === "string" ? safeHostFromUrlString(rawUrl) : "unknown";
      notifyAnalyzeFailedGeneric({
        urlHost,
        classification: "analyze_invalid_body",
        errorCode: codes.BAD_REQUEST,
        actionHint: "Client sent a body that failed analyze schema validation.",
      });
      throw new AppError(codes.BAD_REQUEST, "Invalid body", 400);
    }
    const ctx = request.deviceCtx!;
    const urlHostHint = safeHostFromUrlString(parsed.data.url);
    logAnalyzePerf({
      stage: "analyze_request_received",
      durationMs: 0,
      urlHost: urlHostHint,
      cacheHit: false,
      result: "accepted",
    });
    try {
      await assertUnderDailyAnalyzeLimit(app.redis, ctx.id, config.ANALYZE_DAILY_LIMIT);
    } catch (e) {
      if (e instanceof AppError) {
        notifyAnalyzeFailedGeneric({
          urlHost: urlHostHint,
          classification: "analyze_daily_rate_limit",
          errorCode: e.code,
          actionHint: "Device exceeded analyze daily quota.",
        });
      }
      throw e;
    }
    await incrementAnalyzeCount(app.redis, ctx.id);
    // Sub-stages + analyze_total are logged inside analyzeUrl ([Perf][Analyze]).
    const result = await analyzeUrl(app.prisma, parsed.data.url, { redis: app.redis });
    reply.send(result);
  });
};

export default analyzeRoutes;
