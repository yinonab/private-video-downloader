/**
 * High-level triggers for operational Slack alerts (Instagram / optional Facebook).
 * Call sites pass already-classified yt-dlp outcomes — avoid duplicate alerts via cooldown in alert.service.
 */

import { notifyOperationalAlert, type OperationalAlertContext, type OperationalAlertPayload } from "./alert.service";
import { hostnameIsFacebook, hostnameIsInstagram } from "./urlSafety";
import {
  cookiesFileConfiguredButUnusable,
  platformLabelLooksInstagram,
  stderrIndicatesInstagramRestricted,
  type YtdlpStderrKind,
} from "./ytdlp";

function sanitizeHost(host: string): string {
  const h = host.trim().toLowerCase().slice(0, 253);
  return /^[a-z0-9.-]+$/.test(h) ? h : "unknown";
}

function instagramContextMatches(urlHost: string, platformLabel: string): boolean {
  return hostnameIsInstagram(urlHost) || platformLabelLooksInstagram(platformLabel);
}

/**
 * Instagram yt-dlp failures worth paging on (rate limit, login/cookies, checkpoint-style stderr).
 */
export function triggerYtDlpInstagramOperationalAlert(opts: {
  context: OperationalAlertContext;
  urlHost: string;
  platformLabel: string;
  classification: YtdlpStderrKind;
  stderrTail: string;
}): void {
  const host = sanitizeHost(opts.urlHost);
  const plat = opts.platformLabel.trim() || "unknown";
  if (!instagramContextMatches(host, plat)) return;

  const stderr = opts.stderrTail.toLowerCase();
  const cookiesNote = cookiesFileConfiguredButUnusable();

  const rateLimited =
    opts.classification === "rate_limited" ||
    stderr.includes("rate-limit reached") ||
    stderr.includes("rate limit") ||
    stderr.includes("too many requests") ||
    /\b429\b/.test(stderr);

  if (rateLimited) {
    const payload: OperationalAlertPayload = {
      alertType: "instagram_rate_limited",
      platformLabel: "Instagram",
      classification: "rate_limited",
      context: opts.context,
      urlHost: host,
      actionHint: "Refresh Instagram cookies / check account checkpoint.",
      extraLines: cookiesNote
        ? ["Note: COOKIES_FILE is configured but the cookie jar is missing, empty, or invalid."]
        : undefined,
    };
    notifyOperationalAlert(payload);
    return;
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

    const payload: OperationalAlertPayload = {
      alertType: "instagram_auth_or_restricted",
      platformLabel: "Instagram",
      classification: classificationLabel,
      context: opts.context,
      urlHost: host,
      actionHint: "Refresh Instagram cookies / confirm account is not checkpointed.",
      extraLines: cookiesNote
        ? ["Note: COOKIES_FILE is configured but the cookie jar is missing, empty, or invalid."]
        : undefined,
    };
    notifyOperationalAlert(payload);
  }
}

/** Facebook HTML fallback exhausted MP4 candidates (clean reason from extractor). */
export function triggerFacebookNoMp4CandidatesAlert(opts: {
  context: "analyze";
  urlHost: string;
}): void {
  const host = sanitizeHost(opts.urlHost);
  if (!hostnameIsFacebook(host)) return;

  notifyOperationalAlert({
    alertType: "facebook_no_mp4_candidates",
    platformLabel: "Facebook",
    classification: "no_mp4_candidates",
    context: opts.context,
    urlHost: host,
    actionHint: "Inspect Facebook fallback extractor / page signals; may be temporary blocking.",
  });
}
