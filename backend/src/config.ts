import dotenv from "dotenv";
import { z } from "zod";
import path from "node:path";

dotenv.config();

/** Env booleans must not use `Boolean("false")` semantics (non-empty string → true). */
export function parseBooleanEnv(value: string | undefined, defaultValue: boolean): boolean {
  if (value == null || value === "") return defaultValue;
  const normalized = value.trim().toLowerCase();
  if (["true", "1", "yes", "y", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "n", "off"].includes(normalized)) return false;
  return defaultValue;
}

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().min(1),
  STORAGE_DIR: z.string().min(1),
  COOKIES_FILE: z.string().optional(),
  ADMIN_TOKEN: z.string().min(8),
  DEVICE_TOKEN_SECRET: z.string().min(16),
  DOWNLOAD_CONCURRENCY: z.coerce.number().min(1).default(3),
  DEFAULT_DAILY_LIMIT: z.coerce.number().min(1).default(20),
  ANALYZE_DAILY_LIMIT: z.coerce.number().min(1).default(200),
  MAX_LOCAL_VIDEO_UPLOAD_MB: z.coerce.number().min(1).default(175),
  MAX_LOCAL_VIDEO_UPLOAD_DURATION_SECONDS: z.coerce.number().min(1).default(420),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

const raw = parsed.data;

function parseCooldownMinutes(raw: string | undefined, defaultMinutes: number): number {
  const n = Number(raw ?? "");
  if (!Number.isFinite(n)) return defaultMinutes;
  return Math.max(1, Math.min(24 * 60, Math.floor(n)));
}

export const config = {
  ...raw,
  AUTO_REGISTER_DEVICES: parseBooleanEnv(process.env.AUTO_REGISTER_DEVICES, false),
  REQUIRE_INVITE_CODE: parseBooleanEnv(process.env.REQUIRE_INVITE_CODE, true),
  /** Operational Slack webhooks (optional; see alert.service.ts). */
  alertsEnabled: parseBooleanEnv(process.env.ALERTS_ENABLED, false),
  alertChannel: (process.env.ALERT_CHANNEL ?? "").trim().toLowerCase(),
  alertCooldownMinutes: parseCooldownMinutes(process.env.ALERT_COOLDOWN_MINUTES, 30),
  slackWebhookUrl: (process.env.SLACK_WEBHOOK_URL ?? "").trim(),
  alertGenericCooldownMinutes: parseCooldownMinutes(process.env.ALERT_GENERIC_COOLDOWN_MINUTES, 5),
  storageDir: path.resolve(raw.STORAGE_DIR),
  cookiesFile: raw.COOKIES_FILE ? path.resolve(raw.COOKIES_FILE) : undefined,
  isDev: raw.NODE_ENV === "development",
  maxLocalVideoUploadBytes: Math.min(
    Number.MAX_SAFE_INTEGER,
    Math.floor(raw.MAX_LOCAL_VIDEO_UPLOAD_MB * 1024 * 1024)
  ),
  maxLocalVideoUploadDurationSeconds: raw.MAX_LOCAL_VIDEO_UPLOAD_DURATION_SECONDS,

  /** Captions V1 (`operations` captions burn-in via OpenAI transcript). Omit to disable captions by default */
  openaiApiKey: (process.env.OPENAI_API_KEY ?? "").trim(),
  openaiTranscriptionModel: (
    ((process.env.OPENAI_TRANSCRIPTION_MODEL ?? "").trim() || "whisper-1")
  ).trim(),

  /** V3.4B — canvas overlay for wordHighlight=color|box (ASS for none). */
  captionHighlightOverlay: parseBooleanEnv(process.env.LINKCLIP_CAPTION_HIGHLIGHT_OVERLAY, true),
};

export type AppConfig = typeof config;