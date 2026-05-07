import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { config } from "../config";
import { logger } from "./logger";

export interface YtdlpFormatRow {
  format_id?: string;
  ext?: string;
  height?: number;
  width?: number;
  vcodec?: string;
  acodec?: string;
  filesize?: number;
  filesize_approx?: number;
  url?: string;
}

export interface YtdlpVideoInfo {
  id?: string;
  title?: string;
  thumbnail?: string;
  duration?: number;
  extractor?: string;
  webpage_url?: string;
  formats?: YtdlpFormatRow[];
}

const YT_DLP = process.env.YT_DLP_PATH || "yt-dlp";

/** Skip re-reading / re-validating on hot paths; invalidate when mtime changes. */
const MAX_COOKIES_FILE_BYTES = 512 * 1024;

let cookiesArgsMemo: { path: string; mtimeMs: number; args: string[] } | null = null;

const warnedCookiesKeys = new Set<string>();

function cookiesWarnOnce(key: string, details: Record<string, unknown>, message: string): void {
  if (warnedCookiesKeys.has(key)) return;
  warnedCookiesKeys.add(key);
  logger.warn(details, message);
}

function isProbableNetscapeCookieRow(line: string): boolean {
  const parts = line.split("\t");
  if (parts.length < 7) return false;
  const domain = parts[0];
  if (!domain || domain.startsWith("#")) return false;
  const includeSubdomains = parts[1];
  const secureFlag = parts[3];
  const expires = parts[4];
  if (includeSubdomains !== "TRUE" && includeSubdomains !== "FALSE") return false;
  if (secureFlag !== "TRUE" && secureFlag !== "FALSE") return false;
  if (!/^\d+$/.test(expires)) return false;
  return true;
}

/**
 * True when content looks like Netscape cookies.txt: at least one tab-separated cookie row
 * matching browser cookie-export shape (domain, TRUE/FALSE, path, TRUE/FALSE, unix expiry, name, value…).
 * Not a full parser — enough to reject empty files, random text, and obvious non-Netscape placeholders.
 */
export function looksLikeNetscapeCookiesFileContent(content: string): boolean {
  let cookieRows = 0;

  for (const raw of content.split(/\r?\n/)) {
    const line = raw.replace(/\s+$/, "");
    if (!line || line.startsWith("#")) continue;
    if (isProbableNetscapeCookieRow(line)) cookieRows++;
  }

  return cookieRows >= 1;
}

/**
 * Returns `["--cookies", path]` only when COOKIES_FILE is set and the file exists, is non-empty,
 * and looks like Netscape format. Otherwise returns [] and logs at most once per failure mode per process.
 */
export function getValidatedCookiesArgs(): string[] {
  const configured = config.cookiesFile?.trim();
  if (!configured) {
    return [];
  }

  const p = configured;

  if (!fs.existsSync(p)) {
    cookiesWarnOnce(
      `missing:${p}`,
      { cookiesFile: p },
      "COOKIES_FILE configured but file does not exist; continuing without cookies"
    );
    return [];
  }

  let st: fs.Stats;
  try {
    st = fs.statSync(p);
  } catch {
    cookiesWarnOnce(
      `stat:${p}`,
      { cookiesFile: p },
      "COOKIES_FILE configured but file cannot be accessed; continuing without cookies"
    );
    return [];
  }

  if (cookiesArgsMemo && cookiesArgsMemo.path === p && cookiesArgsMemo.mtimeMs === st.mtimeMs) {
    return cookiesArgsMemo.args;
  }

  let buf: Buffer;
  try {
    buf = fs.readFileSync(p);
  } catch {
    cookiesWarnOnce(
      `read:${p}`,
      { cookiesFile: p },
      "COOKIES_FILE configured but file cannot be read; continuing without cookies"
    );
    cookiesArgsMemo = { path: p, mtimeMs: st.mtimeMs, args: [] };
    return [];
  }

  if (buf.length === 0) {
    cookiesWarnOnce(`empty:${p}`, { cookiesFile: p }, "COOKIES_FILE is empty; continuing without cookies");
    cookiesArgsMemo = { path: p, mtimeMs: st.mtimeMs, args: [] };
    return [];
  }

  if (buf.length > MAX_COOKIES_FILE_BYTES) {
    cookiesWarnOnce(
      `large:${p}`,
      { cookiesFile: p, bytes: buf.length, maxBytes: MAX_COOKIES_FILE_BYTES },
      "COOKIES_FILE exceeds maximum allowed size; continuing without cookies"
    );
    cookiesArgsMemo = { path: p, mtimeMs: st.mtimeMs, args: [] };
    return [];
  }

  const text = buf.toString("utf8");
  if (!text.trim()) {
    cookiesWarnOnce(`empty:${p}`, { cookiesFile: p }, "COOKIES_FILE is empty; continuing without cookies");
    cookiesArgsMemo = { path: p, mtimeMs: st.mtimeMs, args: [] };
    return [];
  }

  if (!looksLikeNetscapeCookiesFileContent(text)) {
    cookiesWarnOnce(
      `invalid:${p}`,
      { cookiesFile: p },
      "COOKIES_FILE is not a valid Netscape cookies file; continuing without cookies"
    );
    cookiesArgsMemo = { path: p, mtimeMs: st.mtimeMs, args: [] };
    return [];
  }

  const args = ["--cookies", p];
  cookiesArgsMemo = { path: p, mtimeMs: st.mtimeMs, args };
  return args;
}

export type YtdlpStderrKind =
  | "auth_required"
  | "rate_limited"
  | "private_content"
  | "not_available"
  | "network_error"
  | "unknown";

/** Case-insensitive substring classification for logs / telemetry (not shown raw to clients). */
export function classifyYtDlpStderr(stderr: string): YtdlpStderrKind {
  const s = stderr.toLowerCase();
  if (
    /\b(connection refused|connection reset|connection aborted|econnreset|econnrefused|enetunreach|network unreachable|failed to establish)\b/.test(
      s
    ) ||
    /\b(timeout|timed out)\b/.test(s)
  ) {
    return "network_error";
  }
  if (/rate-limit|rate limit|too many requests|\b429\b/.test(s)) {
    return "rate_limited";
  }
  if (
    /login required|login page|registered users|authentication|use --cookies|cookies-from-browser/.test(s)
  ) {
    return "auth_required";
  }
  if (/friends only|members only|private video|\bprivate\b/.test(s)) {
    return "private_content";
  }
  if (/not available|does not exist|removed|unavailable|no longer available|video unavailable/.test(s)) {
    return "not_available";
  }
  return "unknown";
}

export function parseYtDlpProgress(line: string): { progress: number; speedText: string; etaText: string } | null {
  const match = line.match(/\[download\]\s+(\d+\.?\d*)%.*?at\s+([^\s]+).*?ETA\s+([^\s]+)/);
  if (!match) return null;
  return {
    progress: Math.min(100, Math.floor(Number(match[1]))),
    speedText: match[2],
    etaText: match[3],
  };
}

export async function fetchMetadataJson(url: string): Promise<YtdlpVideoInfo> {
  const args = [...getValidatedCookiesArgs(), "--dump-json", "--no-playlist", "--no-warnings", url];
  const { stdout, stderr, code } = await runYtDlp(args, { timeoutMs: 120_000 });
  if (code !== 0) {
    const classification = classifyYtDlpStderr(stderr ?? "");
    logger.warn(
      { code, classification, stderrTail: stderr?.slice(-2000) },
      "yt-dlp metadata failed"
    );
    throw new Error(stderr?.slice(0, 2000) || "yt-dlp failed");
  }
  const line = stdout.trim().split("\n").filter(Boolean).pop();
  if (!line) throw new Error("Empty yt-dlp output");
  return JSON.parse(line) as YtdlpVideoInfo;
}

export type DownloadFormatKind = "best" | "1080p" | "720p" | "480p" | "audio_mp3" | "tiktok_ready";

/** yt-dlp `-f` selector for worker logs / diagnostics */
export const YT_DLP_FORMAT_PRIMARY: Record<Exclude<DownloadFormatKind, never>, string> = {
  best: "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
  /** Same source chain as best; TikTok normalization runs after download only for `tiktok_ready`. */
  tiktok_ready: "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
  "1080p":
    "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best[height<=1080]/best[ext=mp4]/best",
  "720p":
    "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]/best[ext=mp4]/best",
  "480p":
    "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best[height<=480]/best[ext=mp4]/best",
  audio_mp3: "bestaudio/best",
};

export function extractFormatArg(args: string[]): string | undefined {
  const i = args.indexOf("-f");
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return undefined;
}

export function buildDownloadArgs(opts: {
  url: string;
  deviceId: string;
  jobId: string;
  format: DownloadFormatKind;
}): { args: string[]; subdir: "videos" | "audio"; pattern: string } {
  const baseOut = path.join(config.storageDir, "devices", opts.deviceId);

  if (opts.format === "audio_mp3") {
    const out = path.join(baseOut, "audio", `${opts.jobId}.%(ext)s`);
    const formatSelector = YT_DLP_FORMAT_PRIMARY.audio_mp3;
    return {
      subdir: "audio",
      pattern: path.join(baseOut, "audio", `${opts.jobId}.%(ext)s`),
      args: [
        ...getValidatedCookiesArgs(),
        "-f",
        formatSelector,
        "--extract-audio",
        "--audio-format",
        "mp3",
        "--audio-quality",
        "0",
        "--no-playlist",
        "--newline",
        "-o",
        out,
        opts.url,
      ],
    };
  }

  const out = path.join(baseOut, "videos", `${opts.jobId}.%(ext)s`);
  const formatSelector = YT_DLP_FORMAT_PRIMARY[opts.format];

  return {
    subdir: "videos",
    pattern: path.join(baseOut, "videos", `${opts.jobId}.%(ext)s`),
    args: [
      ...getValidatedCookiesArgs(),
      "-f",
      formatSelector,
      "--merge-output-format",
      "mp4",
      "--no-playlist",
      "--concurrent-fragments",
      "4",
      "--newline",
      "-o",
      out,
      opts.url,
    ],
  };
}

export function runYtDlpStreaming(
  args: string[],
  handlers: {
    onStdoutLine: (line: string) => void;
    onStderrLine: (line: string) => void;
  }
): { child: ReturnType<typeof spawn>; done: Promise<{ code: number | null }> } {
  const child = spawn(YT_DLP, args, { stdio: ["ignore", "pipe", "pipe"] });
  child.stdout?.on("data", (buf: Buffer) => {
    buf
      .toString("utf8")
      .split("\n")
      .forEach((l) => l && handlers.onStdoutLine(l));
  });
  child.stderr?.on("data", (buf: Buffer) => {
    buf
      .toString("utf8")
      .split("\n")
      .forEach((l) => l && handlers.onStderrLine(l));
  });
  const done = new Promise<{ code: number | null }>((resolve) => {
    child.on("close", (code) => resolve({ code }));
  });
  return { child, done };
}

function runYtDlp(
  args: string[],
  opts: { timeoutMs: number }
): Promise<{ stdout: string; stderr: string; code: number | null }> {
  return new Promise((resolve, reject) => {
    const child = spawn(YT_DLP, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const t = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error("yt-dlp timeout"));
    }, opts.timeoutMs);
    child.stdout?.on("data", (d) => (stdout += d.toString()));
    child.stderr?.on("data", (d) => (stderr += d.toString()));
    child.on("error", (err) => {
      clearTimeout(t);
      reject(err);
    });
    child.on("close", (code) => {
      clearTimeout(t);
      resolve({ stdout, stderr, code });
    });
  });
}

export function stderrMeansUnavailableFormat(stderr: string): boolean {
  return /requested format is not available/i.test(stderr);
}

/** Stored on [DownloadJob.error]; Flutter maps to localized copy. */
export const LINKCLIP_ERR_QUALITY_UNAVAILABLE = "LINKCLIP_ERR_QUALITY_UNAVAILABLE";
export const LINKCLIP_ERR_QUALITY_FALLBACK_FAILED = "LINKCLIP_ERR_QUALITY_FALLBACK_FAILED";
export const LINKCLIP_ERR_INSTAGRAM_RESTRICTED = "LINKCLIP_ERR_INSTAGRAM_RESTRICTED";
export const LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE = "LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE";
export const LINKCLIP_ERR_GENERIC = "LINKCLIP_ERR_GENERIC";

function platformLooksInstagram(platformLabel: string): boolean {
  return platformLabel.toLowerCase().includes("instagram");
}

/** Instagram / reel flows that surface yt-dlp login, csrf, cookie hints, etc. */
export function stderrIndicatesInstagramRestricted(stderr: string): boolean {
  const s = stderr.toLowerCase();
  const needles = [
    "login required",
    "rate-limit reached",
    "no csrf token",
    "main webpage is locked behind the login page",
    "requested content is not available",
    "use --cookies",
    "cookies-from-browser",
  ];
  return needles.some((n) => s.includes(n));
}

export function stderrIndicatesUnsupportedOrPrivate(stderr: string): boolean {
  const s = stderr.toLowerCase();
  return (
    /private video|members only|video unavailable|this video is no longer available|removed by uploader|deleted/.test(s) ||
    /not available in your country|geo.?blocked|blocked in your region/.test(s)
  );
}

/**
 * Stable machine-readable job error for the DB/API. Never returns raw yt-dlp stderr;
 * callers must log stderr separately (e.g. worker `stderrTail` field).
 */
export function formatDownloadFailureMessage(
  stderrTail: string,
  attemptedFallback: boolean,
  platformLabel: string
): string {
  const tail = stderrTail.trim();
  if (stderrMeansUnavailableFormat(tail)) {
    return attemptedFallback ? LINKCLIP_ERR_QUALITY_FALLBACK_FAILED : LINKCLIP_ERR_QUALITY_UNAVAILABLE;
  }
  if (platformLooksInstagram(platformLabel) && stderrIndicatesInstagramRestricted(tail)) {
    return LINKCLIP_ERR_INSTAGRAM_RESTRICTED;
  }
  if (stderrIndicatesUnsupportedOrPrivate(tail)) {
    return LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE;
  }
  return LINKCLIP_ERR_GENERIC;
}

export async function getYtDlpVersion(): Promise<string> {
  const { stdout, code } = await runYtDlp(["--version"], { timeoutMs: 10_000 });
  if (code !== 0) return "unknown";
  return stdout.trim();
}
