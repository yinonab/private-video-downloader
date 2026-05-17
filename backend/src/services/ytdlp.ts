import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import fs from "node:fs";
import fsPromises from "node:fs/promises";
import os from "node:os";
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

/**
 * yt-dlp enables **only Deno** for JS challenges by default (`options.py` default js_runtimes).
 * Our Docker/API image ships Node + yt-dlp-ejs; Deno is not installed → no runtime enabled unless we opt into Node.
 */
export const YTDLP_JS_RUNTIME_ARGS = ["--no-js-runtimes", "--js-runtimes", "node"] as const;

/** Skip re-reading / re-validating on hot paths; invalidate when mtime changes. */
const MAX_COOKIES_FILE_BYTES = 512 * 1024;

/** Memo: same resolved secrets path + mtime → same validation outcome (readable absolute path or unusable). */
let cookiesValidationMemo: { resolvedPath: string; mtimeMs: number; usableSourcePath: string | null } | null = null;

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
 * Absolute path to the validated read-only cookies source, or `null` to omit `--cookies`.
 * Does not return a path yt-dlp should write to — use [withYtDlpCookiesArgs] for invocations.
 */
function resolveValidatedCookiesSourcePathSync(): string | null {
  const configured = config.cookiesFile?.trim();
  if (!configured) {
    return null;
  }

  const p = configured;

  if (!fs.existsSync(p)) {
    cookiesWarnOnce(
      `missing:${p}`,
      { cookiesFile: p },
      "COOKIES_FILE configured but file does not exist; continuing without cookies"
    );
    return null;
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
    return null;
  }

  if (
    cookiesValidationMemo &&
    cookiesValidationMemo.resolvedPath === p &&
    cookiesValidationMemo.mtimeMs === st.mtimeMs
  ) {
    return cookiesValidationMemo.usableSourcePath;
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
    cookiesValidationMemo = { resolvedPath: p, mtimeMs: st.mtimeMs, usableSourcePath: null };
    return null;
  }

  if (buf.length === 0) {
    cookiesWarnOnce(`empty:${p}`, { cookiesFile: p }, "COOKIES_FILE is empty; continuing without cookies");
    cookiesValidationMemo = { resolvedPath: p, mtimeMs: st.mtimeMs, usableSourcePath: null };
    return null;
  }

  if (buf.length > MAX_COOKIES_FILE_BYTES) {
    cookiesWarnOnce(
      `large:${p}`,
      { cookiesFile: p, bytes: buf.length, maxBytes: MAX_COOKIES_FILE_BYTES },
      "COOKIES_FILE exceeds maximum allowed size; continuing without cookies"
    );
    cookiesValidationMemo = { resolvedPath: p, mtimeMs: st.mtimeMs, usableSourcePath: null };
    return null;
  }

  const text = buf.toString("utf8");
  if (!text.trim()) {
    cookiesWarnOnce(`empty:${p}`, { cookiesFile: p }, "COOKIES_FILE is empty; continuing without cookies");
    cookiesValidationMemo = { resolvedPath: p, mtimeMs: st.mtimeMs, usableSourcePath: null };
    return null;
  }

  if (!looksLikeNetscapeCookiesFileContent(text)) {
    cookiesWarnOnce(
      `invalid:${p}`,
      { cookiesFile: p },
      "COOKIES_FILE is not a valid Netscape cookies file; continuing without cookies"
    );
    cookiesValidationMemo = { resolvedPath: p, mtimeMs: st.mtimeMs, usableSourcePath: null };
    return null;
  }

  cookiesValidationMemo = { resolvedPath: p, mtimeMs: st.mtimeMs, usableSourcePath: p };
  return p;
}

/**
 * Runs `fn` with `--cookies` pointing at a writable temp copy of the validated secrets file.
 * yt-dlp may update the cookie jar on exit; the read-only mount must never be passed directly.
 * Temp files are unique per call (pid + random) and removed in `finally`.
 */
export async function withYtDlpCookiesArgs<T>(fn: (cookiesArgs: string[]) => Promise<T>): Promise<T> {
  const source = resolveValidatedCookiesSourcePathSync();
  if (!source) {
    return fn([]);
  }

  const tmpDir = process.platform === "win32" ? os.tmpdir() : "/tmp";
  const tmpPath = path.join(
    tmpDir,
    `linkclip-cookies-${process.pid}-${randomBytes(8).toString("hex")}.txt`
  );

  try {
    await fsPromises.copyFile(source, tmpPath);
  } catch (e) {
    logger.warn({ err: e instanceof Error ? e.message : String(e) }, "failed to copy cookies to temp; continuing without cookies");
    return fn([]);
  }

  try {
    return await fn(["--cookies", tmpPath]);
  } finally {
    await fsPromises.unlink(tmpPath).catch(() => {});
  }
}

export type YtdlpStderrKind =
  | "auth_required"
  | "rate_limited"
  | "private_content"
  | "not_available"
  | "network_error"
  | "unsupported_url"
  | "format_unavailable"
  | "unknown";

export class YtdlpMetadataError extends Error {
  constructor(
    readonly classification: YtdlpStderrKind,
    readonly stderrTail: string
  ) {
    super("yt-dlp metadata failed");
    this.name = "YtdlpMetadataError";
  }
}

/**
 * Avoid inherited `-f` / opts from deployment yt-dlp config breaking `--dump-json`.
 * Strips any env var whose name looks like a yt-dlp / youtube-dl options carrier.
 */
export function ytDlpMetadataEnv(): NodeJS.ProcessEnv {
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (/^(YTDLP|YT_DLP|YOUTUBE_DL|YTDL)/i.test(key)) {
      delete env[key];
    }
  }
  return env;
}

/** Metadata-only: broad fallbacks if default format resolution fails (still `--skip-download`, no real download). */
const YTDLP_METADATA_FORMAT_FALLBACKS: string[][] = [
  ["-f", "best/bestvideo+bestaudio/best"],
  ["-f", "worst/worstvideo+worstaudio/worst"],
  ["-f", "bv*+ba/b"],
  ["-f", "*"],
];

/** Case-insensitive substring classification for logs / telemetry (not shown raw to clients). */
/** Facebook extractor breakage — safe to attempt HTML/JSON fallback when host is Facebook. */
export function stderrIndicatesFacebookCannotParseData(stderr: string): boolean {
  return /cannot parse data/i.test(stderr);
}

export function classifyYtDlpStderr(stderr: string): YtdlpStderrKind {
  const s = stderr.toLowerCase();

  if (/requested format is not available/i.test(s)) {
    return "format_unavailable";
  }
  if (/\bunsupported url\b/i.test(s)) {
    return "unsupported_url";
  }

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
  if (
    /no longer available|video unavailable|does not exist|removed by|removed|this video is unavailable/.test(s)
  ) {
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
  return withYtDlpCookiesArgs(async (cookiesArgs) => {
    const env = ytDlpMetadataEnv();
    /** `--skip-download`: metadata-only; avoids failing format merges that only matter when downloading. */
    const metaCore = [
      ...cookiesArgs,
      ...YTDLP_JS_RUNTIME_ARGS,
      "--no-config",
      "--skip-download",
      "--dump-json",
      "--no-playlist",
      "--no-warnings",
    ];

    const parseStdout = (stdout: string): YtdlpVideoInfo => {
      const line = stdout.trim().split("\n").filter(Boolean).pop();
      if (!line) {
        throw new YtdlpMetadataError("unknown", "empty yt-dlp stdout");
      }
      try {
        return JSON.parse(line) as YtdlpVideoInfo;
      } catch {
        throw new YtdlpMetadataError("unknown", "invalid yt-dlp json");
      }
    };

    const runAttempt = (formatExtra: string[]) =>
      runYtDlp([...metaCore, ...formatExtra, url], { timeoutMs: 120_000, env });

    let { stdout, stderr, code } = await runAttempt([]);
    if (code === 0) {
      return parseStdout(stdout);
    }

    let classification = classifyYtDlpStderr(stderr ?? "");
    const fmtMiss =
      classification === "format_unavailable" || stderrMeansUnavailableFormat(stderr ?? "");

    if (!fmtMiss) {
      logger.warn(
        { code, classification, stderrTail: (stderr ?? "").slice(-2000) },
        "yt-dlp metadata failed"
      );
      throw new YtdlpMetadataError(classification, (stderr ?? "").slice(-2000));
    }

    for (const fmt of YTDLP_METADATA_FORMAT_FALLBACKS) {
      ({ stdout, stderr, code } = await runAttempt(fmt));
      if (code === 0) {
        return parseStdout(stdout);
      }
      classification = classifyYtDlpStderr(stderr ?? "");
      const stillFmt =
        classification === "format_unavailable" || stderrMeansUnavailableFormat(stderr ?? "");
      if (!stillFmt) {
        logger.warn(
          { code, classification, stderrTail: (stderr ?? "").slice(-2000) },
          "yt-dlp metadata failed"
        );
        throw new YtdlpMetadataError(classification, (stderr ?? "").slice(-2000));
      }
    }

    logger.warn(
      { code, classification, stderrTail: (stderr ?? "").slice(-2000) },
      "yt-dlp metadata failed after format fallbacks"
    );
    throw new YtdlpMetadataError(classification, (stderr ?? "").slice(-2000));
  });
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

/** yt-dlp args without `--cookies` — prefix via [withYtDlpCookiesArgs] at invocation time. */
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
        ...YTDLP_JS_RUNTIME_ARGS,
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
      ...YTDLP_JS_RUNTIME_ARGS,
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
  opts: { timeoutMs: number; env?: NodeJS.ProcessEnv }
): Promise<{ stdout: string; stderr: string; code: number | null }> {
  return new Promise((resolve, reject) => {
    const child = spawn(YT_DLP, args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: opts.env ?? process.env,
    });
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
