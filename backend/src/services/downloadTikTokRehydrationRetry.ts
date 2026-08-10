import {
  isTikTokTransientExtractionFailure,
  isTikTokTransientExtractionRetryEligible,
  TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS,
} from "./ytdlpAnalyzeErrors";
import { hostnameIsTikTok } from "./urlSafety";
import { logger } from "./logger";
import { startPerfTimer } from "./downloadPerf";
import type { YtdlpStderrKind } from "./ytdlp";

export type DownloadYtDlpAttemptFn = () => Promise<number>;

export type DownloadTikTokRetryOutcome = {
  code: number;
  /** Total primary-selector yt-dlp calls (1–3). Does not count format-unavailable fallbacks. */
  attempts: number;
  retryEligible: boolean;
  retryResult: "success" | "failure" | "not_attempted";
};

/**
 * Primary download yt-dlp with TikTok transient-family retries (Rank 4).
 * Eligible: tiktok_rehydration | tiktok_webpage_unexpected.
 * Immediate retries. Max 3 primary attempts. Format-unavailable fallbacks stay outside.
 */
export async function runPrimaryYtDlpWithTikTokRehydrationRetry(opts: {
  runAttempt: DownloadYtDlpAttemptFn;
  /** Called after each attempt to read classification from the latest stderr. */
  classifyAfterAttempt: () => YtdlpStderrKind;
  urlHost: string;
  platformLabel: string;
  jobId?: string;
  /** Optional cleanup of partial jobId.* outputs before retry. */
  clearPartials?: () => Promise<void>;
}): Promise<DownloadTikTokRetryOutcome> {
  const platform = hostnameIsTikTok(opts.urlHost)
    ? "tiktok"
    : /tiktok/i.test(opts.platformLabel)
      ? "tiktok"
      : opts.platformLabel || "unknown";

  const maxAttempts = TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS;
  let sawRetryEligible = false;
  let lastCode = 1;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const timer = startPerfTimer();
    const code = (await opts.runAttempt()) ?? 1;
    const durationMs = timer.elapsedMs();
    lastCode = code;

    if (code === 0) {
      const retryResult = sawRetryEligible ? "success" : "not_attempted";
      logger.info(
        {
          downloadTikTokRetry: true,
          platform,
          context: "download_worker",
          attempt,
          maxAttempts,
          transientFamily: false,
          durationMs: Math.round(durationMs),
          retryEligible: false,
          retryStarted: false,
          retryResult,
          ...(opts.jobId ? { jobId: opts.jobId } : {}),
        },
        attempt === 1
          ? "download yt-dlp first attempt success"
          : "download yt-dlp TikTok transient retry success"
      );
      return {
        code: 0,
        attempts: attempt,
        retryEligible: sawRetryEligible,
        retryResult,
      };
    }

    const classification = opts.classifyAfterAttempt();
    const transientFamily = isTikTokTransientExtractionFailure(classification);
    const retryEligible = isTikTokTransientExtractionRetryEligible({
      urlHost: opts.urlHost,
      classification,
      attempt,
      maxAttempts,
    });

    logger.info(
      {
        downloadTikTokRetry: true,
        platform,
        context: "download_worker",
        attempt,
        maxAttempts,
        classification,
        transientFamily,
        durationMs: Math.round(durationMs),
        retryEligible,
        retryStarted: retryEligible,
        retryResult: "not_attempted",
        ...(opts.jobId ? { jobId: opts.jobId } : {}),
      },
      retryEligible
        ? "download yt-dlp TikTok transient failure; retrying"
        : "download yt-dlp non-retryable or final failure"
    );

    if (!retryEligible) {
      return {
        code,
        attempts: attempt,
        retryEligible: sawRetryEligible,
        retryResult: sawRetryEligible ? "failure" : "not_attempted",
      };
    }

    sawRetryEligible = true;
    if (opts.clearPartials) {
      await opts.clearPartials();
    }
    // Immediate next attempt (no artificial delay).
  }

  return {
    code: lastCode,
    attempts: maxAttempts,
    retryEligible: true,
    retryResult: "failure",
  };
}
