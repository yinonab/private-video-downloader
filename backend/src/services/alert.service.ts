/**
 * Operational alerts (Slack Incoming Webhook). Failures here must never break API/workers.
 */

import { config } from "../config";
import { logger } from "./logger";

export type OperationalAlertContext = "analyze" | "worker";

export type OperationalAlertPayload = {
  /** Dedupe/cooldown key segment, e.g. instagram_rate_limited */
  alertType: string;
  /** Human-readable platform, e.g. Instagram */
  platformLabel: string;
  /** Classification / stderr bucket, no raw stderr */
  classification: string;
  context: OperationalAlertContext;
  /** Hostname only (sanitized) */
  urlHost: string;
  actionHint: string;
  /** Optional extra bullet lines (already sanitized, no paths/secrets) */
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

function slackCooldownKey(payload: OperationalAlertPayload): string {
  const type = sanitizeAlertToken(payload.alertType, 80);
  const plat = sanitizeAlertToken(payload.platformLabel.replace(/\s+/g, "_"), 40);
  const host = sanitizeHostname(payload.urlHost);
  return `${type}|${plat}|${host}`;
}

function buildSlackText(payload: OperationalAlertPayload): string {
  const host = sanitizeHostname(payload.urlHost);
  const title =
    payload.platformLabel.toLowerCase().includes("facebook") && payload.alertType.includes("facebook")
      ? "LinkClip Facebook issue"
      : payload.platformLabel.toLowerCase().includes("instagram") || payload.alertType.includes("instagram")
        ? "LinkClip Instagram issue"
        : "LinkClip operational alert";

  const lines = [
    `🚨 ${title}`,
    `Type: ${sanitizeAlertToken(payload.alertType, 80)}`,
    `Platform: ${payload.platformLabel.trim().slice(0, 80)}`,
    `Classification: ${sanitizeAlertToken(payload.classification.replace(/\s+/g, "_"), 80)}`,
    `Context: ${payload.context}`,
    `Host: ${host}`,
    `Action: ${payload.actionHint.trim().slice(0, 500)}`,
  ];
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
      logger.warn({ alertChannel: channel }, "ALERT_CHANNEL is set but only \"slack\" is supported; alerts disabled");
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
  const cooldownMs = config.alertCooldownMinutes * 60_000;
  const until = cooldownUntilMs.get(key) ?? 0;
  if (now < until) {
    logger.info(
      { cooldownKey: key, alertType: payload.alertType, urlHost: sanitizeHostname(payload.urlHost) },
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
