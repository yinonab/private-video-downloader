import { logger } from "./logger";
import { startPerfTimer } from "./downloadPerf";

export { startPerfTimer };

export type AnalyzePerfFields = {
  stage: string;
  durationMs: number;
  platform?: string;
  urlHost?: string;
  formatCount?: number;
  qualityCount?: number;
  thumbnailPresent?: boolean;
  cacheHit?: boolean;
  result?: string;
  classification?: string;
  /** 1-based yt-dlp metadata attempt (Analyze TikTok transient retry). */
  attempt?: number;
  maxAttempts?: number;
  transientFamily?: boolean;
  retryEligible?: boolean;
  retryStarted?: boolean;
  /** success | failure | not_attempted */
  retryResult?: string;
};

/**
 * Structured Analyze timing logs (`[Perf][Analyze]`).
 * Never pass URLs, tokens, cookies, secrets, or stderr bodies.
 */
export function logAnalyzePerf(fields: AnalyzePerfFields): void {
  const {
    stage,
    durationMs,
    platform,
    urlHost,
    formatCount,
    qualityCount,
    thumbnailPresent,
    cacheHit,
    result,
    classification,
    attempt,
    maxAttempts,
    transientFamily,
    retryEligible,
    retryStarted,
    retryResult,
  } = fields;

  const parts = [`[Perf][Analyze] stage=${stage}`, `durationMs=${Math.round(durationMs)}`];
  if (platform) parts.push(`platform=${platform}`);
  if (urlHost) parts.push(`urlHost=${urlHost}`);
  if (formatCount != null) parts.push(`formatCount=${formatCount}`);
  if (qualityCount != null) parts.push(`qualityCount=${qualityCount}`);
  if (thumbnailPresent != null) parts.push(`thumbnailPresent=${thumbnailPresent}`);
  if (cacheHit != null) parts.push(`cacheHit=${cacheHit}`);
  if (result) parts.push(`result=${result}`);
  if (classification) parts.push(`classification=${classification}`);
  if (attempt != null) parts.push(`attempt=${attempt}`);
  if (maxAttempts != null) parts.push(`maxAttempts=${maxAttempts}`);
  if (transientFamily != null) parts.push(`transientFamily=${transientFamily}`);
  if (retryEligible != null) parts.push(`retryEligible=${retryEligible}`);
  if (retryStarted != null) parts.push(`retryStarted=${retryStarted}`);
  if (retryResult) parts.push(`retryResult=${retryResult}`);

  logger.info({ perfAnalyze: true, ...fields }, parts.join(" "));
}

export function countYtdlpFormats(meta: { formats?: unknown }): number {
  const formats = meta.formats;
  if (!Array.isArray(formats)) return 0;
  return formats.filter((x) => x != null && typeof x === "object").length;
}
