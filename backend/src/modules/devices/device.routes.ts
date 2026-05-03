import { FastifyPluginAsync } from "fastify";
import { authDevice } from "../../middleware/authDevice";
import { registerDeviceSchema } from "./device.schemas";
import { registerDevice } from "./device.service";
import { AppError, codes } from "../../types/errors";
import { config } from "../../config";

const deviceRoutes: FastifyPluginAsync = async (app) => {
  app.get("/devices/me", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const d = await app.prisma.device.findUnique({
      where: { id: ctx.id },
      select: { id: true, name: true, platform: true, dailyLimit: true, status: true, createdAt: true, lastSeenAt: true },
    });
    if (!d) {
      throw new AppError(codes.DEVICE_NOT_REGISTERED, "Device not found", 404);
    }
    reply.send({
      deviceId: d.id,
      name: d.name ?? null,
      platform: d.platform ?? null,
      dailyLimit: d.dailyLimit,
      analyzeDailyLimit: config.ANALYZE_DAILY_LIMIT,
      status: d.status,
      createdAt: d.createdAt.toISOString(),
      lastSeenAt: d.lastSeenAt.toISOString(),
    });
  });

  app.post("/devices/register", async (request, reply) => {
    const parsed = registerDeviceSchema.safeParse(request.body);
    if (!parsed.success) {
      reply.status(400).send({
        error: {
          code: "BAD_REQUEST",
          message: "Invalid body",
          details: parsed.error.flatten(),
        },
      });
      return;
    }
    const result = await registerDevice(app.prisma, parsed.data);
    reply.send(result);
  });
};

export default deviceRoutes;
