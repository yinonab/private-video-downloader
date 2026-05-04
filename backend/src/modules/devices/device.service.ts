import type { InviteCode, PrismaClient } from "@prisma/client";
import { AppError, codes } from "../../types/errors";
import { generateDeviceToken, hashDeviceToken } from "../../services/hashing";
import { config } from "../../config";
import type { RegisterDeviceInput } from "./device.schemas";
import { logger } from "../../services/logger";

async function loadValidInvite(prisma: PrismaClient, codeNormalized: string): Promise<InviteCode> {
  const invite = await prisma.inviteCode.findUnique({
    where: { code: codeNormalized },
  });
  if (!invite || !invite.active) {
    throw new AppError(codes.INVITE_CODE_INVALID, "Invite code is invalid", 400);
  }
  if (invite.expiresAt && invite.expiresAt < new Date()) {
    throw new AppError(codes.INVITE_CODE_EXPIRED, "Invite code expired", 400);
  }
  return invite;
}

export async function registerDevice(prisma: PrismaClient, input: RegisterDeviceInput) {
  const inviteTrimmed = (input.inviteCode ?? "").trim();
  const inviteCodeProvided = inviteTrimmed.length > 0;

  logger.info(
    {
      autoRegisterDevices: config.AUTO_REGISTER_DEVICES,
      requireInviteCode: config.REQUIRE_INVITE_CODE,
      inviteCodeProvided,
      deviceId: input.deviceId,
    },
    "device register request"
  );

  const existing = await prisma.device.findUnique({ where: { id: input.deviceId } });
  const rawToken = generateDeviceToken();
  const tokenHash = hashDeviceToken(rawToken, config.DEVICE_TOKEN_SECRET);

  if (existing) {
    if (config.REQUIRE_INVITE_CODE) {
      if (!inviteCodeProvided) {
        throw new AppError(codes.BAD_REQUEST, "Invite code required", 400);
      }
      await loadValidInvite(prisma, inviteTrimmed);
    }
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

  if (inviteCodeProvided) {
    const invite = await loadValidInvite(prisma, inviteTrimmed);
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

    logger.info({ deviceId: input.deviceId }, "device registered (invite)");
    return {
      deviceId: input.deviceId,
      deviceToken: rawToken,
      status: "active" as const,
    };
  }

  if (config.REQUIRE_INVITE_CODE) {
    throw new AppError(codes.BAD_REQUEST, "Invite code required", 400);
  }

  if (!config.AUTO_REGISTER_DEVICES) {
    throw new AppError(codes.BAD_REQUEST, "Auto registration disabled", 400);
  }

  await prisma.device.create({
    data: {
      id: input.deviceId,
      tokenHash,
      name: input.deviceName ?? null,
      platform: input.platform ?? null,
      dailyLimit: config.DEFAULT_DAILY_LIMIT,
    },
  });

  logger.info({ deviceId: input.deviceId }, "device registered (open enrollment)");
  return {
    deviceId: input.deviceId,
    deviceToken: rawToken,
    status: "active" as const,
  };
}
