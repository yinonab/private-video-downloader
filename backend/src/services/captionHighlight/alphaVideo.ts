import { spawn } from "node:child_process";
import { createCanvas, loadImage } from "@napi-rs/canvas";
import type { TimedPlate } from "./types";

/**
 * Production overlay intermediate: ProRes 4444 MOV with alpha (`yuva444p10le`).
 * VP9 WebM alpha was dropped — ffmpeg final `overlay` often treated missing alpha as
 * opaque black, hiding the base video. ProRes 4444 preserves alpha reliably in Docker ffmpeg.
 */
export const CAPTION_ALPHA_VIDEO_CODEC = "prores_ks";
export const CAPTION_ALPHA_VIDEO_PROFILE = "4";
export const CAPTION_ALPHA_VIDEO_PIX_FMT = "yuva444p10le";
export const CAPTION_ALPHA_VIDEO_FPS = 30;
export const CAPTION_ALPHA_VIDEO_EXT = ".mov";

/** Explicit rgba overlay pad before compositing onto the edited base video. */
export const CAPTION_ALPHA_OVERLAY_FILTER =
  "[1:v]format=rgba[cap];[0:v][cap]overlay=0:0:format=auto:shortest=1[vout]";

export type AlphaVideoBuildResult = {
  readonly frameCount: number;
  readonly fps: number;
  readonly codec: string;
  readonly pixFmt: string;
};

/**
 * Encode timed PNG plates into one transparent overlay video (pipe RGBA frames → ProRes 4444).
 * Final edit encode uses only main + this file (two inputs).
 */
export async function buildCaptionHighlightAlphaVideo(opts: {
  readonly plates: readonly TimedPlate[];
  readonly width: number;
  readonly height: number;
  readonly durationSec: number;
  readonly outputPath: string;
}): Promise<AlphaVideoBuildResult> {
  const { plates, width, height, outputPath } = opts;
  if (!plates.length) {
    throw new Error("caption_alpha_video_no_plates");
  }

  const fps = CAPTION_ALPHA_VIDEO_FPS;
  const duration = Math.max(0.1, opts.durationSec);
  const totalFrames = Math.max(1, Math.ceil(duration * fps));
  const schedule: (string | null)[] = new Array<string | null>(totalFrames).fill(null);

  for (const p of plates) {
    const i0 = Math.max(0, Math.min(totalFrames, Math.floor(p.startSec * fps)));
    const i1 = Math.max(i0 + 1, Math.min(totalFrames, Math.ceil(p.endSec * fps)));
    for (let i = i0; i < i1; i++) {
      schedule[i] = p.platePath;
    }
  }

  const args = [
    "-hide_banner",
    "-y",
    "-f",
    "rawvideo",
    "-pix_fmt",
    "rgba",
    "-s",
    `${width}x${height}`,
    "-r",
    String(fps),
    "-i",
    "pipe:0",
    "-c:v",
    CAPTION_ALPHA_VIDEO_CODEC,
    "-profile:v",
    CAPTION_ALPHA_VIDEO_PROFILE,
    "-pix_fmt",
    CAPTION_ALPHA_VIDEO_PIX_FMT,
    "-an",
    outputPath,
  ];

  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext("2d");
  const frameBytes = width * height * 4;

  await new Promise<void>((resolve, reject) => {
    const child = spawn("ffmpeg", args, { stdio: ["pipe", "ignore", "pipe"] });
    let stderr = "";
    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      if (stderr.length > 64_000) stderr = stderr.slice(-32_000);
    });

    let currentPath: string | null = null;
    let img: Awaited<ReturnType<typeof loadImage>> | null = null;

    const pump = async (): Promise<void> => {
      try {
        for (let f = 0; f < totalFrames; f++) {
          ctx.clearRect(0, 0, width, height);
          const platePath = schedule[f];
          if (platePath) {
            if (platePath !== currentPath) {
              img = await loadImage(platePath);
              currentPath = platePath;
            }
            if (img) {
              ctx.drawImage(img, 0, 0, width, height);
            }
          }
          const { data } = ctx.getImageData(0, 0, width, height);
          const frameBuf = Buffer.from(data.buffer, data.byteOffset, frameBytes);
          const ok = child.stdin.write(frameBuf);
          if (!ok) {
            await new Promise<void>((r) => child.stdin.once("drain", r));
          }
        }
        child.stdin.end();
      } catch (err) {
        child.stdin.destroy();
        reject(err);
      }
    };

    void pump();

    child.on("error", (err) => reject(err));
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`caption_alpha_video_ffmpeg_exit_${code ?? "null"}:${stderr.slice(-600)}`));
    });
  });

  return {
    frameCount: totalFrames,
    fps,
    codec: CAPTION_ALPHA_VIDEO_CODEC,
    pixFmt: CAPTION_ALPHA_VIDEO_PIX_FMT,
  };
}
