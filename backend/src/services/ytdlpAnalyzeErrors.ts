import { codes } from "../types/errors";
import { hostnameIsFacebook, hostnameIsTikTok, hostnameIsYouTube } from "./urlSafety";
import {
  stderrIndicatesYouTubeAuthChallenge,
  type YtdlpStderrKind,
} from "./ytdlp";

/**
 * Exactly one retry after a first-attempt TikTok rehydration failure.
 * Shared gate for Analyze (Rank 2) and download worker (Rank 3).
 */
export function isTikTokRehydrationRetryEligible(opts: {
  urlHost: string;
  classification: YtdlpStderrKind;
  /** 1-based attempt that just failed */
  attempt: number;
}): boolean {
  if (opts.attempt !== 1) return false;
  if (opts.classification !== "tiktok_rehydration") return false;
  return hostnameIsTikTok(opts.urlHost);
}

/** @deprecated Prefer {@link isTikTokRehydrationRetryEligible} — Analyze Rank 2 alias. */
export function isAnalyzeTikTokRehydrationRetryEligible(opts: {
  urlHost: string;
  classification: YtdlpStderrKind;
  attempt: number;
}): boolean {
  return isTikTokRehydrationRetryEligible(opts);
}

/**
 * Download-worker Rank 3: same eligibility as Analyze Rank 2 (TikTok host + rehydration + attempt 1).
 */
export function isWorkerTikTokRehydrationRetryEligible(opts: {
  urlHost: string;
  platformLabel?: string;
  classification: YtdlpStderrKind;
  attempt: number;
}): boolean {
  return isTikTokRehydrationRetryEligible(opts);
}

export type YtdlpAnalyzeFailureMapping = {
  code: string;
  classification: YtdlpStderrKind;
  platform?: string;
  message: string;
  statusCode: number;
};

/** Maps classified yt-dlp stderr to typed analyze API errors. Returns null when no specialized mapping applies. */
export function mapYtdlpAnalyzeFailure(
  classification: YtdlpStderrKind,
  urlHost: string,
  stderrTail: string
): YtdlpAnalyzeFailureMapping | null {
  if (classification === "geo_restricted") {
    return {
      code: codes.YOUTUBE_GEO_RESTRICTED,
      classification: "geo_restricted",
      platform: "youtube",
      message: "This video is not available in the download server's region.",
      statusCode: 422,
    };
  }

  if (classification === "no_formats_found") {
    if (hostnameIsFacebook(urlHost)) {
      return {
        code: codes.FACEBOOK_NO_FORMATS_FOUND,
        classification: "no_formats_found",
        platform: "facebook",
        message: "We couldn't find downloadable formats for this Facebook video.",
        statusCode: 422,
      };
    }
    return {
      code: codes.NO_DOWNLOADABLE_FORMATS,
      classification: "no_formats_found",
      message: "We couldn't find downloadable formats for this link.",
      statusCode: 422,
    };
  }

  if (classification === "auth_required") {
    if (stderrIndicatesYouTubeAuthChallenge(stderrTail) || hostnameIsYouTube(urlHost)) {
      return {
        code: codes.YOUTUBE_AUTH_REQUIRED,
        classification: "auth_required",
        platform: "youtube",
        message: "YouTube requires verification for this link.",
        statusCode: 422,
      };
    }
  }

  return null;
}

/** Cooldown key shape used by operational Slack alerts for analyze failures. */
export function analyzeFailureCooldownKey(classification: string, urlHost: string): string {
  const host = urlHost.trim().toLowerCase().slice(0, 253) || "unknown";
  const cls = classification.replace(/\s+/g, "_").slice(0, 80);
  return `analyze_failed|analyze|${host}|${cls}`;
}
