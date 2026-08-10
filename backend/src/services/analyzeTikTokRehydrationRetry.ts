import {
  isTikTokTransientExtractionFailure,
  isTikTokTransientExtractionRetryEligible,
  TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS,
} from "./ytdlpAnalyzeErrors";
import { hostnameIsTikTok } from "./urlSafety";
import { logger } from "./logger";
import { logAnalyzePerf, startPerfTimer } from "./analyzePerf";
import {
  fetchMetadataJson,
  YtdlpMetadataError,
  type YtdlpVideoInfo,
} from "./ytdlp";

export type AnalyzeMetadataFetchFn = (url: string) => Promise<YtdlpVideoInfo>;

export type AnalyzeMetadataFetchSuccess = {
  ok: true;
  meta: YtdlpVideoInfo;
  /** Total yt-dlp metadata calls made (1–3). */
  attempts: number;
  retryEligible: boolean;
  retryResult: "success" | "not_attempted";
};

export type AnalyzeMetadataFetchFailure = {
  ok: false;
  /** Final attempt's metadata error (classification for terminal Analyze handling). */
  error: YtdlpMetadataError;
  attempts: number;
  retryEligible: boolean;
  retryResult: "failure" | "not_attempted";
};

export type AnalyzeMetadataFetchOutcome = AnalyzeMetadataFetchSuccess | AnalyzeMetadataFetchFailure;

function platformLabel(urlHost: string): string {
  return hostnameIsTikTok(urlHost) ? "tiktok" : "unknown";
}

/**
 * Analyze metadata fetch with TikTok transient-family retries (Rank 4).
 * Eligible classes: tiktok_rehydration | tiktok_webpage_unexpected.
 * Immediate retries. Max 3 primary attempts. Worker must not call this.
 */
export async function fetchMetadataJsonForAnalyze(
  url: string,
  urlHost: string,
  fetchFn: AnalyzeMetadataFetchFn = fetchMetadataJson
): Promise<AnalyzeMetadataFetchOutcome> {
  const platform = platformLabel(urlHost);
  const maxAttempts = TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS;
  let sawRetryEligible = false;
  let lastError: YtdlpMetadataError | null = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const timer = startPerfTimer();
    try {
      const meta = await fetchFn(url);
      const durationMs = timer.elapsedMs();
      const retryResult = sawRetryEligible ? "success" : "not_attempted";
      logAnalyzePerf({
        stage: "analyze_ytdlp_metadata_attempt",
        durationMs,
        platform,
        urlHost,
        result: "success",
        attempt,
        maxAttempts,
        transientFamily: false,
        retryEligible: false,
        retryResult,
        retryStarted: false,
      });
      logger.info(
        {
          analyzeTikTokRetry: true,
          platform,
          context: "analyze",
          stage: "analyze_ytdlp_metadata",
          attempt,
          maxAttempts,
          transientFamily: false,
          durationMs: Math.round(durationMs),
          retryEligible: false,
          retryStarted: false,
          retryResult,
        },
        attempt === 1
          ? "analyze metadata first attempt success"
          : "analyze metadata TikTok transient retry success"
      );
      return {
        ok: true,
        meta,
        attempts: attempt,
        retryEligible: sawRetryEligible,
        retryResult,
      };
    } catch (err) {
      const durationMs = timer.elapsedMs();
      if (!(err instanceof YtdlpMetadataError)) {
        throw err;
      }
      lastError = err;
      const transientFamily = isTikTokTransientExtractionFailure(err.classification);
      const retryEligible = isTikTokTransientExtractionRetryEligible({
        urlHost,
        classification: err.classification,
        attempt,
        maxAttempts,
      });

      logAnalyzePerf({
        stage: "analyze_ytdlp_metadata_attempt",
        durationMs,
        platform,
        urlHost,
        result: "failure",
        classification: err.classification,
        attempt,
        maxAttempts,
        transientFamily,
        retryEligible,
        retryResult: "not_attempted",
        retryStarted: retryEligible,
      });
      logger.info(
        {
          analyzeTikTokRetry: true,
          platform,
          context: "analyze",
          stage: "analyze_ytdlp_metadata",
          attempt,
          maxAttempts,
          classifiedErrorType: err.classification,
          transientFamily,
          durationMs: Math.round(durationMs),
          retryEligible,
          retryStarted: retryEligible,
          retryResult: "not_attempted",
        },
        retryEligible
          ? "analyze metadata TikTok transient failure; retrying"
          : "analyze metadata non-retryable or final failure"
      );

      if (!retryEligible) {
        return {
          ok: false,
          error: err,
          attempts: attempt,
          retryEligible: sawRetryEligible,
          retryResult: sawRetryEligible ? "failure" : "not_attempted",
        };
      }

      sawRetryEligible = true;
      // Immediate next attempt (no artificial delay).
    }
  }

  // Exhausted maxAttempts with transient failures only.
  return {
    ok: false,
    error: lastError!,
    attempts: maxAttempts,
    retryEligible: true,
    retryResult: "failure",
  };
}
