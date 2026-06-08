/**
 * Operational Slack triggers: Instagram/Facebook (critical tier) + generic analyze/download failures.
 * One notification per failure — Instagram critical suppresses duplicate generic for the same event.
 */

import { codes } from "../types/errors";
import {
  notifyOperationalAlert,
  type OperationalAlertContext,
  type OperationalAlertPayload,
} from "./alert.service";
import { hostnameIsFacebook, hostnameIsInstagram } from "./urlSafety";
import {
  cookiesFileConfiguredButUnusable,
  platformLabelLooksInstagram,
  stderrIndicatesInstagramRestricted,
  type YtdlpStderrKind,
} from "./ytdlp";

export function safeHostFromUrlString(urlString: string): string {
  const raw = urlString.trim();
  if (!raw) return "unknown";
  try {
    const candidate = /^https?:\/\//i.test(raw) ? raw : `https://${raw}`;
    return new URL(candidate).hostname.toLowerCase();
  } catch {
    return "unknown";
  }
}

function sanitizeHost(host: string): string {
  const h = host.trim().toLowerCase().slice(0, 253);
  return /^[a-z0-9.-]+$/.test(h) ? h : "unknown";
}

function instagramContextMatches(urlHost: string, platformLabel: string): boolean {
  return hostnameIsInstagram(urlHost) || platformLabelLooksInstagram(platformLabel);
}

/**
 * Sends Instagram session/rate-limit alerts (critical cooldown). Returns true if an alert was sent.
 */
export function tryNotifyInstagramYtDlpCritical(opts: {
  context: OperationalAlertContext;
  urlHost: string;
  platformLabel: string;
  classification: YtdlpStderrKind;
  stderrTail: string;
  jobId?: string;
  deviceIdPrefix?: string;
}): boolean {
  const host = sanitizeHost(opts.urlHost);
  const plat = opts.platformLabel.trim() || "unknown";
  if (!instagramContextMatches(host, plat)) return false;

  const stderr = opts.stderrTail.toLowerCase();
  const cookiesNote = cookiesFileConfiguredButUnusable();

  const rateLimited =
    opts.classification === "rate_limited" ||
    stderr.includes("rate-limit reached") ||
    stderr.includes("rate limit") ||
    stderr.includes("too many requests") ||
    /\b429\b/.test(stderr);

  const extras = cookiesNote
    ? ["Note: COOKIES_FILE is configured but the cookie jar is missing, empty, or invalid."]
    : undefined;

  const common: Pick<
    OperationalAlertPayload,
    "context" | "urlHost" | "platformLabel" | "cooldownTier" | "jobId" | "deviceIdPrefix" | "extraLines"
  > = {
    context: opts.context,
    urlHost: host,
    platformLabel: "Instagram",
    cooldownTier: "critical",
    jobId: opts.jobId,
    deviceIdPrefix: opts.deviceIdPrefix,
    extraLines: extras,
  };

  if (rateLimited) {
    notifyOperationalAlert({
      ...common,
      alertType: "instagram_rate_limited",
      headline: "LinkClip Instagram issue",
      classification: "rate_limited",
      errorCode: "INSTAGRAM_RATE_LIMITED",
      actionHint: "Refresh Instagram cookies / check account checkpoint.",
    });
    return true;
  }

  const authOrCheckpoint =
    opts.classification === "auth_required" ||
    stderr.includes("login required") ||
    stderr.includes("use --cookies") ||
    stderr.includes("checkpoint") ||
    stderr.includes("challenge") ||
    stderr.includes("locked behind the login page");

  const restrictedHeuristic = stderrIndicatesInstagramRestricted(opts.stderrTail);

  if (authOrCheckpoint || restrictedHeuristic) {
    const classificationLabel =
      opts.classification === "auth_required"
        ? "auth_required"
        : restrictedHeuristic
          ? "instagram_restricted"
          : "auth_required";

    notifyOperationalAlert({
      ...common,
      alertType: "instagram_auth_or_restricted",
      headline: "LinkClip Instagram issue",
      classification: classificationLabel,
      errorCode: "INSTAGRAM_AUTH_OR_RESTRICTED",
      actionHint: "Refresh Instagram cookies / confirm account is not checkpointed.",
    });
    return true;
  }

  return false;
}

/** Facebook HTML fallback exhausted MP4 candidates (critical cooldown). */
export function notifyFacebookNoMp4CandidatesAlert(opts: { context: "analyze"; urlHost: string }): void {
  const host = sanitizeHost(opts.urlHost);
  if (!hostnameIsFacebook(host)) return;

  notifyOperationalAlert({
    alertType: "facebook_no_mp4_candidates",
    cooldownTier: "critical",
    headline: "LinkClip Facebook issue",
    platformLabel: "Facebook",
    classification: "no_mp4_candidates",
    context: opts.context,
    urlHost: host,
    errorCode: "FACEBOOK_NO_MP4_CANDIDATES",
    actionHint: "Inspect Facebook fallback extractor / page signals; may be temporary blocking.",
  });
}

/** Generic analyze failure (short cooldown). */
export function notifyAnalyzeFailedGeneric(opts: {
  urlHost: string;
  classification: string;
  errorCode: string;
  platformLabel?: string;
  actionHint?: string;
}): void {
  notifyOperationalAlert({
    alertType: "analyze_failed",
    cooldownTier: "generic",
    headline: "LinkClip analyze failed",
    platformLabel: opts.platformLabel ?? "unknown",
    classification: opts.classification,
    context: "analyze",
    urlHost: sanitizeHost(opts.urlHost),
    errorCode: opts.errorCode,
    actionHint: opts.actionHint ?? "Check platform support or user-facing API error.",
  });
}

function downloadErrorCodeForClassification(
  classification: string,
  facebookDirect: boolean
): string {
  if (facebookDirect) {
    if (classification === "facebook_audio_mp3_unsupported") return "FACEBOOK_AUDIO_MP3_UNSUPPORTED";
    return "FACEBOOK_DIRECT_DOWNLOAD_FAILED";
  }
  switch (classification) {
    case "rate_limited":
      return "DOWNLOAD_RATE_LIMITED";
    case "auth_required":
      return "DOWNLOAD_AUTH_REQUIRED";
    case "network_error":
      return "DOWNLOAD_NETWORK_ERROR";
    case "private_content":
      return "DOWNLOAD_PRIVATE_CONTENT";
    case "not_available":
      return "DOWNLOAD_NOT_AVAILABLE";
    case "unsupported_url":
      return "DOWNLOAD_UNSUPPORTED_URL";
    case "format_unavailable":
      return "DOWNLOAD_FORMAT_UNAVAILABLE";
    case "drm_protected":
      return codes.DRM_PROTECTED;
    default:
      return codes.DOWNLOAD_FAILED;
  }
}

/**
 * Download worker terminal failure: Instagram critical first (same event), else generic download_failed.
 */
export function notifyDownloadWorkerFailed(opts: {
  jobId: string;
  deviceId: string;
  url: string;
  platformLabel: string;
  classification: string;
  facebookDirectFallback: boolean;
  stderrTail?: string;
  stderrClassification?: YtdlpStderrKind;
  actionHint?: string;
}): void {
  const urlHost = sanitizeHost(safeHostFromUrlString(opts.url));
  const devicePrefix = opts.deviceId.slice(0, 8);

  if (
    !opts.facebookDirectFallback &&
    opts.stderrTail != null &&
    opts.stderrClassification != null &&
    tryNotifyInstagramYtDlpCritical({
      context: "download_worker",
      urlHost,
      platformLabel: opts.platformLabel,
      classification: opts.stderrClassification,
      stderrTail: opts.stderrTail,
      jobId: opts.jobId,
      deviceIdPrefix: devicePrefix,
    })
  ) {
    return;
  }

  const errorCode = downloadErrorCodeForClassification(opts.classification, opts.facebookDirectFallback);

  const defaultDownloadHint =
    opts.classification === "drm_protected"
      ? "DRM-protected source — not supported; no bypass attempted."
      : opts.facebookDirectFallback
        ? "Check Facebook direct fallback / CDN availability."
        : "Check yt-dlp stderr in logs, cookies/session, or platform status.";

  notifyOperationalAlert({
    alertType: "download_failed",
    cooldownTier: "generic",
    headline: "LinkClip download failed",
    platformLabel: opts.platformLabel.trim() || "unknown",
    classification: opts.classification,
    context: "download_worker",
    urlHost,
    jobId: opts.jobId,
    deviceIdPrefix: devicePrefix,
    errorCode,
    actionHint: opts.actionHint ?? defaultDownloadHint,
  });
}

/** BullMQ worker threw before job completion (generic cooldown). */
export function notifyDownloadWorkerBullUncaught(opts: {
  jobId: string;
  deviceId: string;
  url: string;
}): void {
  const urlHost = sanitizeHost(safeHostFromUrlString(opts.url));
  notifyOperationalAlert({
    alertType: "download_failed",
    cooldownTier: "generic",
    headline: "LinkClip download failed",
    platformLabel: "unknown",
    classification: "bullmq_uncaught_exception",
    context: "download_worker",
    urlHost,
    jobId: opts.jobId,
    deviceIdPrefix: opts.deviceId.slice(0, 8),
    errorCode: "DOWNLOAD_WORKER_EXCEPTION",
    actionHint: "Inspect worker logs for the stack trace (not sent to Slack).",
  });
}

export function analyzeErrorCodeForYtdlpClassification(c: YtdlpStderrKind): string {
  switch (c) {
    case "drm_protected":
      return codes.DRM_PROTECTED;
    case "unsupported_url":
      return codes.LINKCLIP_ERR_PLATFORM_UNSUPPORTED;
    case "format_unavailable":
      return codes.LINKCLIP_ERR_ANALYZE_METADATA_UNAVAILABLE;
    case "geo_restricted":
      return codes.YOUTUBE_GEO_RESTRICTED;
    case "no_formats_found":
      return codes.NO_DOWNLOADABLE_FORMATS;
    case "auth_required":
      return codes.YOUTUBE_AUTH_REQUIRED;
    default:
      return codes.ANALYZE_FAILED;
  }
}
