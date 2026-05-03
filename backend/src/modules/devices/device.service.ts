import { PrismaClient } from "@prisma/client";
import { AppError, codes } from "../../types/errors";
import { generateDeviceToken, hashDeviceToken } from "../../services/hashing";
import { config } from "../../config";
import type { RegisterDeviceInput } from "./device.schemas";
import { logger } from "../../services/logger";

export async function registerDevice(prisma: PrismaClient, input: RegisterDeviceInput) {
  const codeNormalized = input.inviteCode.trim();

  const invite = await prisma.inviteCode.findUnique({
    where: { code: codeNormalized },
  });

  if (!invite || !invite.active) {
    throw new AppError(codes.INVITE_CODE_INVALID, "Invite code is invalid", 400);
  }
  if (invite.expiresAt && invite.expiresAt < new Date()) {
    throw new AppError(codes.INVITE_CODE_EXPIRED, "Invite code expired", 400);
  }

  const existing = await prisma.device.findUnique({ where: { id: input.deviceId } });
  const rawToken = generateDeviceToken();
  const tokenHash = hashDeviceToken(rawToken, config.DEVICE_TOKEN_SECRET);

  if (existing) {
    const updated = await prisma.device.update({
      where: { id: existing.id },
      data: {
        tokenHash,
        name: input.deviceName ?? existing.name,
        platform: input.platform ?? existing.platform,
      },
    });
    logger.info({ deviceId: updated.id }, "device token rotated");
    return {
      deviceId: updated.id,
      deviceToken: rawToken,
      status: updated.status,
    };
  }

  if (invite.usedCount >= invite.maxUses) {
    throw new AppError(codes.INVITE_CODE_INVALID, "Invite code exhausted", 400);
  }

  await prisma.$transaction([
    prisma.inviteCode.update({
      where: { id: invite.id },
      data: { usedCount: { increment: 1 } },
    }),
    prisma.device.create({
      data: {
        id: input.deviceId,
        tokenHash,
        name: input.deviceName ?? null,
        platform: input.platform ?? null,
        dailyLimit: config.DEFAULT_DAILY_LIMIT,
      },
    }),
  ]);

  logger.info({ deviceId: input.deviceId }, "device registered");

  return {
    deviceId: input.deviceId,
    deviceToken: rawToken,
    status: "active",
  };
}
