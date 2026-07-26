import { spawn } from "node:child_process";

/** Stored on [downloadJob.error]; Flutter maps to localized UI copy. */
export const DOWNLOAD_JOB_ERROR_NORMALIZE_FAILED = "NORMALIZE_FAILED";

const STDERR_CAP = 512_000;

export type NormalizeStrategy = "remux" | "audio_only" | "full_transcode";

export interface ProbeResult {
  durationMs: number;
  /** Comma-separated container ids from ffprobe `format.format_name`. */
  formatName?: string;
  video?: {
    codec: string;
    pixFmt: string;
    width: number;
    height: number;
    profile?: string;
  };
  audio?: {
    codec: string;
    profile?: string;
  };
}

async function runCmd(
  cmd: string,
  args: string[],
  opts?: { onStdoutChunk?: (chunk: string) => void }
): Promise<{ stdout: string; stderr: string; code: number | null }> {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout?.setEncoding("utf8");
    child.stderr?.setEncoding("utf8");
    child.stdout?.on("data", (chunk: string) => {
      stdout += chunk;
      opts?.onStdoutChunk?.(chunk);
      if (stdout.length > 2_000_000) stdout = stdout.slice(-800_000);
    });
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      if (stderr.length > STDERR_CAP) stderr = stderr.slice(-STDERR_CAP);
    });
    child.on("error", (err) => {
      resolve({
        stdout,
        stderr: `${stderr}\nspawn error: ${String(err)}`.slice(-8000),
        code: null,
      });
    });
    child.on("close", (code) => resolve({ stdout, stderr: stderr.trim().slice(-8000), code }));
  });
}

export async function ffprobeMedia(inputPath: string): Promise<ProbeResult> {
  const args = ["-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", inputPath];
  const { stdout, code, stderr } = await runCmd("ffprobe", args);
  if (code !== 0) throw new Error(stderr || "ffprobe failed");
  const j = JSON.parse(stdout) as {
    format?: { duration?: string; format_name?: string };
    streams?: Array<Record<string, unknown>>;
  };
  const formatName =
    j.format?.format_name != null && String(j.format.format_name).trim() !== ""
      ? String(j.format.format_name)
      : undefined;
  const durationSec = j.format?.duration != null ? Number(j.format.duration) : 0;
  const durationMs =
    Number.isFinite(durationSec) && durationSec > 0 ? Math.round(durationSec * 1000) : 0;

  let video: ProbeResult["video"];
  let audio: ProbeResult["audio"];

  for (const s of j.streams ?? []) {
    const codecType = String(s.codec_type ?? "");
    if (codecType === "video" && !video) {
      video = {
        codec: String(s.codec_name ?? ""),
        pixFmt: String(s.pix_fmt ?? ""),
        width: Number(s.width ?? 0),
        height: Number(s.height ?? 0),
        profile: s.profile != null ? String(s.profile) : undefined,
      };
    }
    if (codecType === "audio" && !audio) {
      audio = {
        codec: String(s.codec_name ?? ""),
        profile: s.profile != null ? String(s.profile) : undefined,
      };
    }
  }

  return { durationMs, formatName, video, audio };
}

function videoCompatibleForCopyRemux(v: NonNullable<ProbeResult["video"]>): boolean {
  if (v.codec !== "h264") return false;
  if (v.pixFmt !== "yuv420p") return false;
  if (!Number.isFinite(v.width) || !Number.isFinite(v.height)) return false;
  if (v.width % 2 !== 0 || v.height % 2 !== 0) return false;
  return true;
}

/** AAC streams that are likely AAC-LC / widely compatible for strict players. */
function audioCompatibleForCopyRemux(a: NonNullable<ProbeResult["audio"]>): boolean {
  const c = a.codec.toLowerCase();
  if (c !== "aac") return false;
  const p = (a.profile ?? "").toLowerCase();
  if (p.includes("he-aac") || p.includes("heaac") || p.includes("he aac")) return false;
  if (p.includes(" er ") || p.startsWith("he")) return false;
  return true;
}

export function selectNormalizeStrategy(probe: ProbeResult): NormalizeStrategy {
  const v = probe.video;
  if (!v || !videoCompatibleForCopyRemux(v)) return "full_transcode";
  const a = probe.audio;
  if (!a) return "remux";
  if (!audioCompatibleForCopyRemux(a)) return "audio_only";
  return "remux";
}

/** Safe ffmpeg arg shape for logs — never includes input/output paths. */
export type FfmpegNormalizeCommandShape = {
  hasVideoMap: boolean;
  hasOptionalAudio: boolean;
  videoCodecAction: string;
  audioCodecAction: string;
  audioBitrate: string | null;
  audioSampleRate: string | null;
  movflagsFaststart: boolean;
};

/**
 * Derive a path-free description of normalize ffmpeg args for structured logs.
 * Do not log raw argv (paths appear after `-i` and as the final output).
 */
export function ffmpegNormalizeCommandShape(args: string[]): FfmpegNormalizeCommandShape {
  const hasFlag = (flag: string) => args.includes(flag);
  const valueAfter = (flag: string): string | undefined => {
    const i = args.indexOf(flag);
    if (i < 0 || i + 1 >= args.length) return undefined;
    return args[i + 1];
  };

  let videoCodecAction = "unknown";
  let audioCodecAction = "unknown";
  if (hasFlag("-c") && valueAfter("-c") === "copy") {
    videoCodecAction = "copy";
    audioCodecAction = "copy";
  }
  const cv = valueAfter("-c:v");
  if (cv) videoCodecAction = cv;
  const ca = valueAfter("-c:a");
  if (ca) audioCodecAction = ca;

  return {
    hasVideoMap: hasFlag("0:v:0") || args.some((a) => a === "0:v:0"),
    hasOptionalAudio: hasFlag("0:a?") || args.some((a) => a === "0:a?"),
    videoCodecAction,
    audioCodecAction,
    audioBitrate: valueAfter("-b:a") ?? null,
    audioSampleRate: valueAfter("-ar") ?? null,
    movflagsFaststart: args.some((a) => a.includes("faststart")),
  };
}

export async function runFfmpegRemux(opts: {
  inputPath: string;
  outputTempPath: string;
}): Promise<{ code: number | null; stderrTail: string; args: string[] }> {
  const args = [
    "-y",
    "-i",
    opts.inputPath,
    "-map",
    "0:v:0",
    "-map",
    "0:a?",
    "-c",
    "copy",
    "-movflags",
    "+faststart",
    opts.outputTempPath,
  ];
  const r = await runCmd("ffmpeg", args);
  return { code: r.code, stderrTail: r.stderr, args };
}

export async function runFfmpegAudioNormalize(opts: {
  inputPath: string;
  outputTempPath: string;
}): Promise<{ code: number | null; stderrTail: string; args: string[] }> {
  const args = [
    "-y",
    "-i",
    opts.inputPath,
    "-map",
    "0:v:0",
    "-map",
    "0:a?",
    "-c:v",
    "copy",
    "-c:a",
    "aac",
    "-b:a",
    "128k",
    "-ar",
    "44100",
    "-movflags",
    "+faststart",
    opts.outputTempPath,
  ];
  const r = await runCmd("ffmpeg", args);
  return { code: r.code, stderrTail: r.stderr, args };
}

/**
 * Full transcode + optional progress via `-progress pipe:1`.
 * Progress uses `out_time_ms` from ffmpeg progress protocol (microseconds since ~ffmpeg 4).
 */
export async function runFfmpegFullTranscode(opts: {
  inputPath: string;
  outputTempPath: string;
  durationMs: number;
  onProgress?: (percent0to99: number) => void;
}): Promise<{ code: number | null; stderrTail: string; args: string[] }> {
  const args = [
    "-y",
    "-progress",
    "pipe:1",
    "-nostats",
    "-i",
    opts.inputPath,
    "-map",
    "0:v:0",
    "-map",
    "0:a?",
    "-c:v",
    "libx264",
    "-preset",
    "veryfast",
    "-profile:v",
    "main",
    "-level",
    "4.1",
    "-pix_fmt",
    "yuv420p",
    "-vf",
    "scale=trunc(iw/2)*2:trunc(ih/2)*2",
    "-c:a",
    "aac",
    "-b:a",
    "128k",
    "-ar",
    "44100",
    "-movflags",
    "+faststart",
    opts.outputTempPath,
  ];

  const durationUs =
    opts.durationMs > 0 && Number.isFinite(opts.durationMs) ? opts.durationMs * 1000 : 0;

  let buf = "";
  const onStdoutChunk = (chunk: string) => {
    if (!opts.onProgress || durationUs <= 0) return;
    buf += chunk;
    const lines = buf.split("\n");
    buf = lines.pop() ?? "";
    for (const line of lines) {
      if (!line.startsWith("out_time_ms=")) continue;
      const raw = line.slice("out_time_ms=".length).trim();
      const us = Number(raw);
      if (!Number.isFinite(us) || us < 0) continue;
      const pct = (us / durationUs) * 100;
      opts.onProgress(Math.min(99, pct));
    }
  };

  const r = await runCmd("ffmpeg", args, { onStdoutChunk });
  return { code: r.code, stderrTail: r.stderr, args };
}
