import { logger } from "./logger";

/** Wall-clock timer for download performance instrumentation (safe fields only). */
export function startPerfTimer(): { elapsedMs: () => number } {
  const t0 = Date.now();
  return {
    elapsedMs: () => Math.max(0, Date.now() - t0),
  };
}

export type DownloadPerfFields = {
  stage: string;
  durationMs: number;
  jobId?: string;
  platform?: string;
  quality?: string;
  formatSelector?: string;
  strategy?: string;
  bytes?: number;
  contentLength?: number;
  mime?: string;
  ext?: string;
  mediaDurationMs?: number;
  mergeLikely?: boolean;
  cached?: boolean;
  result?: string;
};

/**
 * Structured, grep-friendly download timing log.
 * Never pass URLs, tokens, cookies, or secrets in [extra].
 */
export function logDownloadPerf(fields: DownloadPerfFields): void {
  const {
    stage,
    durationMs,
    jobId,
    platform,
    quality,
    formatSelector,
    strategy,
    bytes,
    contentLength,
    mime,
    ext,
    mediaDurationMs,
    mergeLikely,
    cached,
    result,
  } = fields;

  const parts = [`[Perf][Download] stage=${stage}`, `durationMs=${Math.round(durationMs)}`];
  if (jobId) parts.push(`jobId=${jobId}`);
  if (platform) parts.push(`platform=${platform}`);
  if (quality) parts.push(`quality=${quality}`);
  if (formatSelector) parts.push(`formatSelector=${formatSelector}`);
  if (strategy) parts.push(`strategy=${strategy}`);
  if (bytes != null) parts.push(`bytes=${bytes}`);
  if (contentLength != null) parts.push(`contentLength=${contentLength}`);
  if (mime) parts.push(`mime=${mime}`);
  if (ext) parts.push(`ext=${ext}`);
  if (mediaDurationMs != null) parts.push(`mediaDurationMs=${Math.round(mediaDurationMs)}`);
  if (mergeLikely != null) parts.push(`mergeLikely=${mergeLikely}`);
  if (cached != null) parts.push(`cached=${cached}`);
  if (result) parts.push(`result=${result}`);

  logger.info({ perfDownload: true, ...fields }, parts.join(" "));
}

/** Heuristic: yt-dlp selectors with "+" usually require a video+audio merge. */
export function formatSelectorSuggestsMerge(selector: string | undefined | null): boolean {
  if (!selector) return false;
  return selector.includes("+");
}
