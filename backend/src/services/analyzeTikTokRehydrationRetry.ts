import { isAnalyzeTikTokRehydrationRetryEligible } from "./ytdlpAnalyzeErrors";
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
  /** Total yt-dlp metadata calls made (1 or 2). */
  attempts: number;
  retryEligible: boolean;
  retryResult: "success" | "not_attempted";
};

export type AnalyzeMetadataFetchFailure = {
  ok: false;
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
 * Analyze metadata fetch with at most one TikTok rehydration retry.
 * Immediate retry (no artificial delay). Max 2 attempts. Worker must not call this.
 */
export async function fetchMetadataJsonForAnalyze(
  url: string,
  urlHost: string,
  fetchFn: AnalyzeMetadataFetchFn = fetchMetadataJson
): Promise<AnalyzeMetadataFetchOutcome> {
  const platform = platformLabel(urlHost);
  const attempt1Timer = startPerfTimer();

  try {
    const meta = await fetchFn(url);
    const durationMs = attempt1Timer.elapsedMs();
    logAnalyzePerf({
      stage: "analyze_ytdlp_metadata_attempt",
      durationMs,
      platform,
      urlHost,
      result: "success",
      attempt: 1,
      retryEligible: false,
      retryResult: "not_attempted",
    });
    logger.info(
      {
        analyzeTikTokRetry: true,
        platform,
        stage: "analyze_ytdlp_metadata",
        attempt: 1,
        durationMs: Math.round(durationMs),
        retryEligible: false,
        retryResult: "not_attempted",
      },
      "analyze metadata first attempt success"
    );
    return {
      ok: true,
      meta,
      attempts: 1,
      retryEligible: false,
      retryResult: "not_attempted",
    };
  } catch (err) {
    const attempt1Ms = attempt1Timer.elapsedMs();
    if (!(err instanceof YtdlpMetadataError)) {
      throw err;
    }

    const retryEligible = isAnalyzeTikTokRehydrationRetryEligible({
      urlHost,
      classification: err.classification,
      attempt: 1,
    });

    logAnalyzePerf({
      stage: "analyze_ytdlp_metadata_attempt",
      durationMs: attempt1Ms,
      platform,
      urlHost,
      result: "failure",
      classification: err.classification,
      attempt: 1,
      retryEligible,
      retryResult: "not_attempted",
    });
    logger.info(
      {
        analyzeTikTokRetry: true,
        platform,
        stage: "analyze_ytdlp_metadata",
        attempt: 1,
        classifiedErrorType: err.classification,
        durationMs: Math.round(attempt1Ms),
        retryEligible,
        retryResult: "not_attempted",
      },
      retryEligible
        ? "analyze metadata first attempt tiktok_rehydration; retrying once"
        : "analyze metadata first attempt non-retryable failure"
    );

    if (!retryEligible) {
      return {
        ok: false,
        error: err,
        attempts: 1,
        retryEligible: false,
        retryResult: "not_attempted",
      };
    }

    const attempt2Timer = startPerfTimer();
    try {
      const meta = await fetchFn(url);
      const attempt2Ms = attempt2Timer.elapsedMs();
      logAnalyzePerf({
        stage: "analyze_ytdlp_metadata_attempt",
        durationMs: attempt2Ms,
        platform,
        urlHost,
        result: "success",
        classification: "tiktok_rehydration",
        attempt: 2,
        retryEligible: true,
        retryResult: "success",
      });
      logger.info(
        {
          analyzeTikTokRetry: true,
          platform,
          stage: "analyze_ytdlp_metadata",
          attempt: 2,
          classifiedErrorType: "tiktok_rehydration",
          durationMs: Math.round(attempt2Ms),
          retryEligible: true,
          retryResult: "success",
        },
        "analyze metadata tiktok_rehydration retry success"
      );
      return {
        ok: true,
        meta,
        attempts: 2,
        retryEligible: true,
        retryResult: "success",
      };
    } catch (retryErr) {
      const attempt2Ms = attempt2Timer.elapsedMs();
      const retryClassification =
        retryErr instanceof YtdlpMetadataError ? retryErr.classification : "unexpected_metadata_error";
      logAnalyzePerf({
        stage: "analyze_ytdlp_metadata_attempt",
        durationMs: attempt2Ms,
        platform,
        urlHost,
        result: "failure",
        classification: retryClassification,
        attempt: 2,
        retryEligible: true,
        retryResult: "failure",
      });
      logger.info(
        {
          analyzeTikTokRetry: true,
          platform,
          stage: "analyze_ytdlp_metadata",
          attempt: 2,
          classifiedErrorType: retryClassification,
          durationMs: Math.round(attempt2Ms),
          retryEligible: true,
          retryResult: "failure",
        },
        "analyze metadata tiktok_rehydration retry failure"
      );
      // Preserve the original first-attempt failure for Analyze error handling.
      return {
        ok: false,
        error: err,
        attempts: 2,
        retryEligible: true,
        retryResult: "failure",
      };
    }
  }
}
