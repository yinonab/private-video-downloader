import Fastify, { type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import multipart from "@fastify/multipart";
import { config } from "./config";
import { fastifyLoggerOptions } from "./services/logger";
import { errorHandler } from "./middleware/errorHandler";
import prismaPlugin from "./plugins/prisma";
import redisPlugin from "./plugins/redis";
import queuesPlugin from "./plugins/queues";
import deviceRoutes from "./modules/devices/device.routes";
import analyzeRoutes from "./modules/analyze/analyze.routes";
import downloadRoutes from "./modules/downloads/download.routes";
import editRoutes from "./modules/edit/edit.routes";
import uploadRoutes from "./modules/uploads/upload.routes";
import adminRoutes from "./modules/admin/admin.routes";

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({ logger: fastifyLoggerOptions });
  app.setErrorHandler(errorHandler);
  await app.register(cors, { origin: true });
  await app.register(prismaPlugin);
  await app.register(redisPlugin);
  await app.register(queuesPlugin);

  await app.register(multipart, {
    limits: {
      fileSize: config.maxLocalVideoUploadBytes,
      files: 1,
      fields: 24,
      parts: 32,
    },
    throwFileSizeLimit: true,
  });

  app.get("/health", async () => ({ ok: true as const }));

  await app.register(deviceRoutes);
  await app.register(analyzeRoutes);
  await app.register(downloadRoutes);
  await app.register(editRoutes);
  await app.register(uploadRoutes);
  await app.register(adminRoutes, { prefix: "/admin" });

  return app;
}
