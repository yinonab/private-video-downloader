/**
 * Operational alerts (Slack Incoming Webhook). Failures here must never break API/workers.
 */

import { config } from "../config";
import { logger } from "./logger";

export type OperationalAlertContext = "analyze" | "download_worker";

export type OperationalAlertCooldownTier = "critical" | "generic";

export type OperationalAlertPayload = {
  /** Dedupe bucket, e.g. analyze_failed, instagram_rate_limited */
  alertType: string;
  cooldownTier: OperationalAlertCooldownTier;
  /** Slack title line after emoji */
  headline: string;
  platformLabel: string;
  /** Logical classification / stderr bucket — never raw stderr */
  classification: string;
  context: OperationalAlertContext;
  /** Hostname only (sanitized) */
  urlHost: string;
  actionHint: string;
  /** App / stable error code */
  errorCode?: string;
  jobId?: string;
  /** Short prefix only — never full device token */
  deviceIdPrefix?: string;
  /** Optional extra lines (sanitized) */
  extraLines?: string[];
};

const cooldownUntilMs = new Map<string, number>();

let warnedMissingWebhook = false;
let warnedUnknownChannel = false;

function sanitizeAlertToken(raw: string, maxLen: number): string {
  const s = raw.trim().toLowerCase().slice(0, maxLen);
  if (!/^[a-z0-9_-]+$/.test(s)) return "unknown";
  return s;
}

function sanitizeHostname(raw: string): string {
  const s = raw.trim().toLowerCase().slice(0, 253);
  if (!/^[a-z0-9.-]+$/.test(s)) return "unknown";
  return s;
}

function sanitizeClassificationForDisplay(raw: string): string {
  return raw.trim().replace(/\s+/g, "_").slice(0, 120) || "unknown";
}

function sanitizeErrorCode(raw: string): string {
  const s = raw.trim().slice(0, 80);
  if (!/^[a-zA-Z0-9_-]+$/.test(s)) return "UNKNOWN";
  return s;
}

function sanitizeJobId(raw: string): string {
  const s = raw.trim().slice(0, 40);
  if (!/^[a-zA-Z0-9-]+$/.test(s)) return "redacted";
  return s;
}

function sanitizeDevicePrefix(raw: string): string {
  const s = raw.trim().toLowerCase().slice(0, 8);
  if (!/^[a-z0-9]+$/.test(s)) return "????????";
  return s;
}

/** Cooldown key: alertType + context + urlHost + classification (all sanitized). */
export function slackCooldownKey(payload: OperationalAlertPayload): string {
  const type = sanitizeAlertToken(payload.alertType, 80);
  const ctx = sanitizeAlertToken(payload.context, 40);
  const host = sanitizeHostname(payload.urlHost);
  const cls = sanitizeAlertToken(payload.classification.replace(/\s+/g, "_"), 80);
  return `${type}|${ctx}|${host}|${cls}`;
}

function cooldownMsForTier(tier: OperationalAlertCooldownTier): number {
  return tier === "critical"
    ? config.alertCooldownMinutes * 60_000
    : config.alertGenericCooldownMinutes * 60_000;
}

function buildSlackText(payload: OperationalAlertPayload): string {
  const host = sanitizeHostname(payload.urlHost);
  const lines = [
    `🚨 ${payload.headline.trim().slice(0, 120)}`,
    `Context: ${payload.context}`,
    `Host: ${host}`,
  ];
  const plat = payload.platformLabel.trim();
  if (plat && plat !== "unknown") {
    lines.push(`Platform: ${plat.slice(0, 80)}`);
  }
  lines.push(`Classification: ${sanitizeClassificationForDisplay(payload.classification)}`);
  if (payload.errorCode) {
    lines.push(`Error code: ${sanitizeErrorCode(payload.errorCode)}`);
  }
  if (payload.jobId) {
    lines.push(`Job ID: ${sanitizeJobId(payload.jobId)}`);
  }
  if (payload.deviceIdPrefix) {
    lines.push(`Device: ${sanitizeDevicePrefix(payload.deviceIdPrefix)}…`);
  }
  lines.push(`Action: ${payload.actionHint.trim().slice(0, 500)}`);
  lines.push(`Time: ${new Date().toISOString()}`);
  if (payload.extraLines?.length) {
    for (const raw of payload.extraLines) {
      const line = raw.trim().slice(0, 400);
      if (line) lines.push(line);
    }
  }
  return lines.join("\n");
}

async function postSlackWebhook(webhookUrl: string, text: string): Promise<void> {
  const res = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=utf-8" },
    body: JSON.stringify({ text }),
  });
  if (!res.ok) {
    logger.warn({ status: res.status }, "slack operational webhook returned non-OK status");
  }
}

/**
 * Sends a sanitized operational alert to Slack when enabled.
 * Fire-and-forget: never throws to callers.
 */
export function notifyOperationalAlert(payload: OperationalAlertPayload): void {
  void deliverOperationalAlert(payload).catch((err) => {
    logger.warn({ err: err instanceof Error ? err.message : String(err) }, "operational alert delivery failed");
  });
}

async function deliverOperationalAlert(payload: OperationalAlertPayload): Promise<void> {
  if (!config.alertsEnabled) return;

  const channel = config.alertChannel;
  if (channel !== "slack") {
    if (!warnedUnknownChannel && channel) {
      warnedUnknownChannel = true;
      logger.warn({ alertChannel: channel }, 'ALERT_CHANNEL is set but only "slack" is supported; alerts disabled');
    }
    return;
  }

  const url = config.slackWebhookUrl;
  if (!url) {
    if (!warnedMissingWebhook) {
      warnedMissingWebhook = true;
      logger.warn("ALERTS_ENABLED=true and ALERT_CHANNEL=slack but SLACK_WEBHOOK_URL is missing");
    }
    return;
  }

  const key = slackCooldownKey(payload);
  const now = Date.now();
  const cooldownMs = cooldownMsForTier(payload.cooldownTier);
  const until = cooldownUntilMs.get(key) ?? 0;
  if (now < until) {
    logger.info(
      { cooldownKey: key, cooldownTier: payload.cooldownTier, alertType: payload.alertType, urlHost: sanitizeHostname(payload.urlHost) },
      "operational alert suppressed (cooldown)"
    );
    return;
  }

  const text = buildSlackText(payload);
  await postSlackWebhook(url, text);
  cooldownUntilMs.set(key, Date.now() + cooldownMs);
}

/**
 * Manual connectivity check — posts a fixed test string only when Slack alerting is configured.
 * Does not print secrets.
 */
export async function sendOperationalAlertTestPing(): Promise<boolean> {
  if (!config.alertsEnabled || config.alertChannel !== "slack") {
    console.error("Set ALERTS_ENABLED=true and ALERT_CHANNEL=slack to run the alert test.");
    return false;
  }
  const url = config.slackWebhookUrl;
  if (!url) {
    console.error("SLACK_WEBHOOK_URL is not set.");
    return false;
  }
  try {
    await postSlackWebhook(url, "✅ LinkClip alert test");
    console.log("Alert test sent (check Slack).");
    return true;
  } catch (e) {
    console.error("Alert test failed:", e instanceof Error ? e.message : String(e));
    return false;
  }
}
