import { FastifyPluginAsync } from "fastify";
import { authDevice } from "../../middleware/authDevice";
import { analyzeBodySchema } from "./analyze.schemas";
import { analyzeUrl } from "./analyze.service";
import { AppError, codes } from "../../types/errors";
import { assertUnderDailyAnalyzeLimit, incrementAnalyzeCount } from "../../services/rateLimit";
import { config } from "../../config";

const analyzeRoutes: FastifyPluginAsync = async (app) => {
  app.post("/analyze", { preHandler: authDevice }, async (request, reply) => {
    const parsed = analyzeBodySchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError(codes.BAD_REQUEST, "Invalid body", 400);
    }
    const ctx = request.deviceCtx!;
    await assertUnderDailyAnalyzeLimit(app.redis, ctx.id, config.ANALYZE_DAILY_LIMIT);
    await incrementAnalyzeCount(app.redis, ctx.id);
    const result = await analyzeUrl(app.prisma, parsed.data.url);
    reply.send(result);
  });
};

export default analyzeRoutes;
