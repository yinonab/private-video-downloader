import { isWorkerTikTokRehydrationRetryEligible } from "./ytdlpAnalyzeErrors";
import { hostnameIsTikTok } from "./urlSafety";
import { logger } from "./logger";
import { startPerfTimer } from "./downloadPerf";
import type { YtdlpStderrKind } from "./ytdlp";

export type DownloadYtDlpAttemptFn = () => Promise<number>;

export type DownloadTikTokRetryOutcome = {
  code: number;
  /** Total primary-selector yt-dlp calls (1 or 2). Does not count format-unavailable fallbacks. */
  attempts: number;
  retryEligible: boolean;
  retryResult: "success" | "failure" | "not_attempted";
};

/**
 * Runs the primary download yt-dlp invocation with at most one TikTok rehydration retry.
 * Immediate retry. Max 2 attempts. Format-unavailable fallbacks stay outside this helper.
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

  const attempt1Timer = startPerfTimer();
  const code1 = (await opts.runAttempt()) ?? 1;
  const attempt1Ms = attempt1Timer.elapsedMs();

  if (code1 === 0) {
    logger.info(
      {
        downloadTikTokRetry: true,
        platform,
        context: "download_worker",
        attempt: 1,
        durationMs: Math.round(attempt1Ms),
        retryEligible: false,
        retryResult: "not_attempted",
        ...(opts.jobId ? { jobId: opts.jobId } : {}),
      },
      "download yt-dlp first attempt success"
    );
    return {
      code: 0,
      attempts: 1,
      retryEligible: false,
      retryResult: "not_attempted",
    };
  }

  const classification = opts.classifyAfterAttempt();
  const retryEligible = isWorkerTikTokRehydrationRetryEligible({
    urlHost: opts.urlHost,
    platformLabel: opts.platformLabel,
    classification,
    attempt: 1,
  });

  logger.info(
    {
      downloadTikTokRetry: true,
      platform,
      context: "download_worker",
      attempt: 1,
      classification,
      durationMs: Math.round(attempt1Ms),
      retryEligible,
      retryResult: "not_attempted",
      retryStarted: retryEligible,
      ...(opts.jobId ? { jobId: opts.jobId } : {}),
    },
    retryEligible
      ? "download yt-dlp first attempt tiktok_rehydration; retrying once"
      : "download yt-dlp first attempt non-retryable failure"
  );

  if (!retryEligible) {
    return {
      code: code1,
      attempts: 1,
      retryEligible: false,
      retryResult: "not_attempted",
    };
  }

  if (opts.clearPartials) {
    await opts.clearPartials();
  }

  const attempt2Timer = startPerfTimer();
  const code2 = (await opts.runAttempt()) ?? 1;
  const attempt2Ms = attempt2Timer.elapsedMs();
  const retryClassification = opts.classifyAfterAttempt();
  const retryResult = code2 === 0 ? "success" : "failure";

  logger.info(
    {
      downloadTikTokRetry: true,
      platform,
      context: "download_worker",
      attempt: 2,
      classification: retryClassification,
      durationMs: Math.round(attempt2Ms),
      retryEligible: true,
      retryResult,
      ...(opts.jobId ? { jobId: opts.jobId } : {}),
    },
    retryResult === "success"
      ? "download yt-dlp tiktok_rehydration retry success"
      : "download yt-dlp tiktok_rehydration retry failure"
  );

  return {
    // On retry failure, prefer attempt-2 exit code/stderr already in caller state.
    // Caller terminal path classifies from lastStderr (attempt 2).
    code: code2,
    attempts: 2,
    retryEligible: true,
    retryResult,
  };
}
