import Redis from "ioredis";
import { AppError, codes } from "../types/errors";

function todayKeyUtc(deviceId: string, prefix: string): string {
  const d = new Date();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${prefix}:${deviceId}:${y}-${m}-${day}`;
}

async function assertUnderDailyKeyedLimit(
  redis: Redis,
  deviceId: string,
  prefix: string,
  dailyLimit: number
): Promise<void> {
  const key = todayKeyUtc(deviceId, prefix);
  const raw = await redis.get(key);
  const count = raw ? Number(raw) : 0;
  if (count >= dailyLimit) {
    throw new AppError(codes.RATE_LIMITED, "Daily limit reached", 429);
  }
}

async function incrementDailyKeyedCount(redis: Redis, deviceId: string, prefix: string): Promise<void> {
  const key = todayKeyUtc(deviceId, prefix);
  const n = await redis.incr(key);
  if (n === 1) {
    await redis.expire(key, 172800);
  }
}

const DL_PREFIX = "dl";
const AN_PREFIX = "an";

export async function assertUnderDailyDownloadLimit(
  redis: Redis,
  deviceId: string,
  dailyLimit: number
): Promise<void> {
  await assertUnderDailyKeyedLimit(redis, deviceId, DL_PREFIX, dailyLimit);
}

export async function incrementDailyDownloadCount(redis: Redis, deviceId: string): Promise<void> {
  await incrementDailyKeyedCount(redis, deviceId, DL_PREFIX);
}

export async function assertUnderDailyAnalyzeLimit(
  redis: Redis,
  deviceId: string,
  analyzeLimit: number
): Promise<void> {
  await assertUnderDailyKeyedLimit(redis, deviceId, AN_PREFIX, analyzeLimit);
}

export async function incrementAnalyzeCount(redis: Redis, deviceId: string): Promise<void> {
  await incrementDailyKeyedCount(redis, deviceId, AN_PREFIX);
}
