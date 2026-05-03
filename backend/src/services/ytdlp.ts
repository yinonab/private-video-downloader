import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { config } from "../config";
import { logger } from "./logger";

export interface YtdlpVideoInfo {
  id?: string;
  title?: string;
  thumbnail?: string;
  duration?: number;
  extractor?: string;
  webpage_url?: string;
}

const YT_DLP = process.env.YT_DLP_PATH || "yt-dlp";

export function parseYtDlpProgress(line: string): { progress: number; speedText: string; etaText: string } | null {
  const match = line.match(/\[download\]\s+(\d+\.?\d*)%.*?at\s+([^\s]+).*?ETA\s+([^\s]+)/);
  if (!match) return null;
  return {
    progress: Math.min(100, Math.floor(Number(match[1]))),
    speedText: match[2],
    etaText: match[3],
  };
}

function cookiesArgs(): string[] {
  const p = config.cookiesFile;
  if (p && fs.existsSync(p)) {
    return ["--cookies", p];
  }
  return [];
}

export async function fetchMetadataJson(url: string): Promise<YtdlpVideoInfo> {
  const args = [...cookiesArgs(), "--dump-json", "--no-playlist", "--no-warnings", url];
  const { stdout, stderr, code } = await runYtDlp(args, { timeoutMs: 120_000 });
  if (code !== 0) {
    logger.warn({ stderr, code }, "yt-dlp metadata failed");
    throw new Error(stderr?.slice(0, 2000) || "yt-dlp failed");
  }
  const line = stdout.trim().split("\n").filter(Boolean).pop();
  if (!line) throw new Error("Empty yt-dlp output");
  return JSON.parse(line) as YtdlpVideoInfo;
}

export type DownloadFormatKind = "best" | "1080p" | "720p" | "audio_mp3";

export function buildDownloadArgs(opts: {
  url: string;
  deviceId: string;
  jobId: string;
  format: DownloadFormatKind;
}): { args: string[]; subdir: "videos" | "audio"; pattern: string } {
  const baseOut = path.join(config.storageDir, "devices", opts.deviceId);

  if (opts.format === "audio_mp3") {
    const out = path.join(baseOut, "audio", `${opts.jobId}.%(ext)s`);
    return {
      subdir: "audio",
      pattern: path.join(baseOut, "audio", `${opts.jobId}.%(ext)s`),
      args: [
        ...cookiesArgs(),
        "-f",
        "bestaudio/best",
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
  let formatSelector: string;
  if (opts.format === "1080p") {
    formatSelector = "bv*[height<=1080]+ba/b[height<=1080]";
  } else if (opts.format === "720p") {
    formatSelector = "bv*[height<=720]+ba/b[height<=720]";
  } else {
    formatSelector = "bv*+ba/b";
  }

  return {
    subdir: "videos",
    pattern: path.join(baseOut, "videos", `${opts.jobId}.%(ext)s`),
    args: [
      ...cookiesArgs(),
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

export async function getYtDlpVersion(): Promise<string> {
  const { stdout, code } = await runYtDlp(["--version"], { timeoutMs: 10_000 });
  if (code !== 0) return "unknown";
  return stdout.trim();
}
