import { logger } from "./logger";
import type { AvailableQualityDto } from "./availableQualities";

export const ANALYZE_RESULT_CACHE_TTL_SEC = 60;
export const ANALYZE_RESULT_CACHE_KEY_PREFIX = "analyze:result:v1:";

/** Narrow Redis surface for Analyze result cache (ioredis-compatible). */
export type AnalyzeResultCacheRedis = {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, expiryMode: "EX", ttlSeconds: number): Promise<unknown>;
  del(key: string): Promise<unknown>;
};

export type AnalyzeResponseDto = {
  url: string;
  platform: string;
  title: string;
  durationSec?: number;
  thumbnail?: string;
  extractor: string;
  availableFormats: ReadonlyArray<{ label: string; value: string; type: string }>;
  availableQualities: AvailableQualityDto[];
};

export function analyzeResultCacheKey(urlHash: string): string {
  return `${ANALYZE_RESULT_CACHE_KEY_PREFIX}${urlHash}`;
}

export function parseAnalyzeResultCachePayload(raw: string): AnalyzeResponseDto | null {
  try {
    const j = JSON.parse(raw) as unknown;
    if (!j || typeof j !== "object") return null;
    const o = j as Record<string, unknown>;
    if (typeof o.url !== "string" || !o.url.trim()) return null;
    if (typeof o.platform !== "string") return null;
    if (typeof o.title !== "string") return null;
    if (typeof o.extractor !== "string") return null;
    if (!Array.isArray(o.availableFormats) || !Array.isArray(o.availableQualities)) return null;
    if (o.durationSec != null && typeof o.durationSec !== "number") return null;
    if (o.thumbnail != null && typeof o.thumbnail !== "string") return null;
    return {
      url: o.url,
      platform: o.platform,
      title: o.title,
      durationSec: typeof o.durationSec === "number" ? o.durationSec : undefined,
      thumbnail: typeof o.thumbnail === "string" ? o.thumbnail : undefined,
      extractor: o.extractor,
      availableFormats: o.availableFormats as AnalyzeResponseDto["availableFormats"],
      availableQualities: o.availableQualities as AvailableQualityDto[],
    };
  } catch {
    return null;
  }
}

export type AnalyzeCacheLookupResult =
  | { status: "hit"; dto: AnalyzeResponseDto }
  | { status: "miss" }
  | { status: "error" }
  | { status: "skipped" };

/** Safe Redis GET — never throws; never logs keys/URLs/payloads. */
export async function lookupAnalyzeResultCache(
  redis: AnalyzeResultCacheRedis | null | undefined,
  urlHash: string
): Promise<AnalyzeCacheLookupResult> {
  if (!redis) return { status: "skipped" };
  try {
    const key = analyzeResultCacheKey(urlHash);
    const raw = await redis.get(key);
    if (raw == null || raw === "") return { status: "miss" };
    const dto = parseAnalyzeResultCachePayload(raw);
    if (!dto) {
      try {
        await redis.del(key);
        logger.warn(
          { analyzeCache: true, op: "delete_invalid" },
          "analyze result cache invalid payload deleted — continuing without cache"
        );
      } catch {
        logger.warn(
          { analyzeCache: true, op: "delete_invalid" },
          "analyze result cache invalid payload delete failed — continuing without cache"
        );
      }
      return { status: "miss" };
    }
    return { status: "hit", dto };
  } catch {
    logger.warn({ analyzeCache: true, op: "get" }, "analyze result cache read failed — continuing without cache");
    return { status: "error" };
  }
}

/** Safe Redis SET EX — never throws; never logs keys/URLs/payloads. */
export async function storeAnalyzeResultCache(
  redis: AnalyzeResultCacheRedis | null | undefined,
  urlHash: string,
  dto: AnalyzeResponseDto
): Promise<"ok" | "error" | "skipped"> {
  if (!redis) return "skipped";
  try {
    await redis.set(
      analyzeResultCacheKey(urlHash),
      JSON.stringify(dto),
      "EX",
      ANALYZE_RESULT_CACHE_TTL_SEC
    );
    return "ok";
  } catch {
    logger.warn({ analyzeCache: true, op: "set" }, "analyze result cache write failed — continuing without cache");
    return "error";
  }
}
