import type { ResolvedEditPlan } from "./edit.types";

export type EditProbeMeta = {
  durationSec: number;
  hasAudio: boolean;
};

export function targetDims(
  aspect: ResolvedEditPlan["aspectRatio"]
): { w: number; h: number } | null {
  switch (aspect) {
    case "original":
      return null;
    case "9:16":
      return { w: 1080, h: 1920 };
    case "1:1":
      return { w: 1080, h: 1080 };
    case "16:9":
      return { w: 1920, h: 1080 };
    case "4:5":
      return { w: 1080, h: 1350 };
    default:
      return null;
  }
}

export function x264EncodeOpts(preset: ResolvedEditPlan["compressPreset"]): {
  crf: string;
  presetName: string;
} {
  switch (preset) {
    case "original":
      return { crf: "20", presetName: "medium" };
    case "social":
      return { crf: "23", presetName: "veryfast" };
    case "small":
      return { crf: "28", presetName: "veryfast" };
    default:
      return { crf: "23", presetName: "veryfast" };
  }
}

export type BuiltEditFfmpeg = {
  args: string[];
  /** Expected output duration (seconds) for progress parsing */
  segmentDurationSec: number;
};

const BLUR_SIGMA = 20;

function buildSpatialVideo(opts: {
  ts: string;
  te: string;
  spd: ResolvedEditPlan["speedFactor"];
  dims: { w: number; h: number } | null;
  formatMode: ResolvedEditPlan["formatMode"];
}): string {
  const { ts, te, spd, dims, formatMode } = opts;

  /** Original aspect / no dims: unchanged single-chain trim + optional constant speed */
  if (dims == null) {
    let v = `[0:v]trim=start=${ts}:end=${te},setpts=PTS-STARTPTS`;
    if (spd != null) v += `,setpts=PTS/${spd}`;
    v += `[vout]`;
    return v;
  }

  const w = dims.w;
  const h = dims.h;
  const fm = formatMode ?? "fill";

  if (fm !== "fit_blur") {
    /** Center-crop fill (legacy behavior): scale to cover frame, crop to exact WxH */
    let v = `[0:v]trim=start=${ts}:end=${te},setpts=PTS-STARTPTS`;
    v += `,scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}`;
    if (spd != null) v += `,setpts=PTS/${spd}`;
    v += `[vout]`;
    return v;
  }

  /** Fit + blurred background layer */
  let g = `[0:v]trim=start=${ts}:end=${te},setpts=PTS-STARTPTS[v1];`;
  g += `[v1]split=2[bg][fg];`;
  g += `[bg]scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h},gblur=sigma=${BLUR_SIGMA}[bb];`;
  g += `[fg]scale=${w}:${h}:force_original_aspect_ratio=decrease[ff];`;
  if (spd != null) {
    g += `[bb][ff]overlay=(W-w)/2:(H-h)/2,setsar=1[v2];`;
    g += `[v2]setpts=PTS/${spd}[vout]`;
  } else {
    g += `[bb][ff]overlay=(W-w)/2:(H-h)/2,setsar=1[vout]`;
  }
  return g;
}

/**
 * Single-pass filter graph: trim → optional format (fill or fit/blur) → constant speed → encode H.264 (+ AAC if audio kept).
 */
export function buildEditFfmpegArgs(opts: {
  inputPath: string;
  outputPath: string;
  probe: EditProbeMeta;
  plan: ResolvedEditPlan;
}): BuiltEditFfmpeg {
  const { inputPath, outputPath, probe, plan } = opts;
  const dur = probe.durationSec > 0 ? probe.durationSec : 0;
  const trimStart = plan.trim?.startSec ?? 0;
  let trimEnd = plan.trim?.endSec ?? dur;
  if (dur > 0) {
    trimEnd = Math.min(trimEnd, dur);
  }
  const trimStartClamped = Math.max(0, Math.min(trimStart, trimEnd - 0.05));
  const trimEndClamped = Math.max(trimStartClamped + 0.05, trimEnd);
  const trimmedSourceSegmentSec = trimEndClamped - trimStartClamped;
  const spd = plan.speedFactor;
  /** Output mux timeline duration (after speed changes playback length). Used for ffmpeg progress ratios. */
  const segmentDurationSec =
    spd != null && spd > 0 ? trimmedSourceSegmentSec / spd : trimmedSourceSegmentSec;

  const ts = trimStartClamped.toFixed(3);
  const te = trimEndClamped.toFixed(3);

  const dims = targetDims(plan.aspectRatio);

  let formatModeForGraph = plan.formatMode ?? "fill";
  if (dims == null || plan.aspectRatio === "original") {
    formatModeForGraph = "fill";
  }

  const vSpatial = buildSpatialVideo({
    ts,
    te,
    spd,
    dims,
    formatMode: formatModeForGraph,
  });

  const filters: string[] = [vSpatial];
  const encodeAudio = !plan.mute && probe.hasAudio;
  if (encodeAudio) {
    let aChain = `[0:a]atrim=start=${ts}:end=${te},asetpts=PTS-STARTPTS`;
    if (spd != null) {
      aChain += `,atempo=${spd}`;
    }
    aChain += "[aout]";
    filters.push(aChain);
  }

  const { crf, presetName } = x264EncodeOpts(plan.compressPreset);

  const args: string[] = [
    "-hide_banner",
    "-nostats",
    "-y",
    "-i",
    inputPath,
    "-filter_complex",
    filters.join(";"),
    "-map",
    "[vout]",
    "-c:v",
    "libx264",
    "-preset",
    presetName,
    "-crf",
    crf,
    "-pix_fmt",
    "yuv420p",
  ];

  if (encodeAudio) {
    args.push("-map", "[aout]", "-c:a", "aac", "-b:a", "128k");
  } else {
    args.push("-an");
  }

  args.push("-movflags", "+faststart", outputPath);

  return { args, segmentDurationSec };
}

export function ffmpegProgressRatio(stderrChunk: string): number | null {
  const lines = stderrChunk.split(/\r?\n/);
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i]!;
    const m = /time=(\d+):(\d+):(\d+(?:\.\d+)?)/i.exec(line);
    if (!m) continue;
    const hh = Number(m[1]);
    const mm = Number(m[2]);
    const ss = Number(m[3]);
    if (!Number.isFinite(hh + mm + ss)) continue;
    const t = hh * 3600 + mm * 60 + ss;
    return t;
  }
  return null;
}
