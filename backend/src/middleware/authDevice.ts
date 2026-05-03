import { FastifyReply, FastifyRequest } from "fastify";
import { config } from "../config";
import { hashDeviceToken } from "../services/hashing";
import { AppError, codes } from "../types/errors";

declare module "fastify" {
  interface FastifyRequest {
    deviceCtx?: { id: string; dailyLimit: number; status: string };
  }
}

export async function authDevice(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const auth = request.headers.authorization;
  if (!auth?.startsWith("Bearer ")) {
    throw new AppError(codes.UNAUTHORIZED, "Missing bearer token", 401);
  }
  const raw = auth.slice("Bearer ".length).trim();
  if (!raw) {
    throw new AppError(codes.UNAUTHORIZED, "Missing bearer token", 401);
  }
  const tokenHash = hashDeviceToken(raw, config.DEVICE_TOKEN_SECRET);
  const device = await request.server.prisma.device.findFirst({
    where: { tokenHash },
  });
  if (!device) {
    throw new AppError(codes.DEVICE_NOT_REGISTERED, "Device not registered", 401);
  }
  if (device.status !== "active") {
    throw new AppError(codes.DEVICE_BLOCKED, "Device is blocked", 403);
  }
  request.deviceCtx = {
    id: device.id,
    dailyLimit: device.dailyLimit,
    status: device.status,
  };
  await request.server.prisma.device.update({
    where: { id: device.id },
    data: { lastSeenAt: new Date() },
  });
}
