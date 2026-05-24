import type { EditRotationDegrees, ResolvedEditPlan } from "./edit.types";

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

/** Clockwise rotation as pixel transpose/flip chains (metadata-only rotate is intentionally not used). */
function rotationFilterChain(degrees: EditRotationDegrees): string {
  switch (degrees) {
    case 90:
      return "transpose=1";
    case 180:
      return "hflip,vflip";
    case 270:
      return "transpose=2";
  }
}

/**
 * Trim → rotate (optional) → format spatial (optional) → setpts speed (optional) → `[vout]`.
 */
function buildSpatialVideo(opts: {
  ts: string;
  te: string;
  spd: ResolvedEditPlan["speedFactor"];
  dims: { w: number; h: number } | null;
  formatMode: ResolvedEditPlan["formatMode"];
  rotationDegrees?: EditRotationDegrees;
}): string {
  const { ts, te, spd, dims, formatMode, rotationDegrees } = opts;
  const chunks: string[] = [];
  let cur = "vtrim";
  chunks.push(`[0:v]trim=start=${ts}:end=${te},setpts=PTS-STARTPTS[${cur}]`);

  if (rotationDegrees != null) {
    const rotated = "vrot";
    chunks.push(`[${cur}]${rotationFilterChain(rotationDegrees)}[${rotated}]`);
    cur = rotated;
  }

  /** Original aspect / no dims */
  if (dims == null) {
    if (spd != null) {
      chunks.push(`[${cur}]setpts=PTS/${spd}[vout]`);
    } else {
      /** Ensures labelled output for `-map`; minimal change vs prior single-graph trim-only path */
      chunks.push(`[${cur}]format=yuv420p[vout]`);
    }
    return chunks.join(";");
  }

  const w = dims.w;
  const h = dims.h;
  const fm = formatMode ?? "fill";

  if (fm !== "fit_blur") {
    /** Center-crop fill: scale to cover frame, crop to exact WxH */
    const geo = `[${cur}]scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}`;
    if (spd != null) {
      const scaled = "vfill";
      chunks.push(`${geo}[${scaled}]`);
      chunks.push(`[${scaled}]setpts=PTS/${spd}[vout]`);
    } else {
      chunks.push(`${geo}[vout]`);
    }
    return chunks.join(";");
  }

  /** Fit + blurred background */
  chunks.push(`[${cur}]split=2[bg][fg]`);
  chunks.push(`[bg]scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h},gblur=sigma=${BLUR_SIGMA}[bb]`);
  chunks.push(`[fg]scale=${w}:${h}:force_original_aspect_ratio=decrease[ff]`);
  if (spd != null) {
    chunks.push(`[bb][ff]overlay=(W-w)/2:(H-h)/2,setsar=1[vovl]`);
    chunks.push(`[vovl]setpts=PTS/${spd}[vout]`);
  } else {
    chunks.push(`[bb][ff]overlay=(W-w)/2:(H-h)/2,setsar=1[vout]`);
  }
  return chunks.join(";");
}

/**
 * Single-pass filter graph: trim → optional rotate → optional format → constant speed → encode H.264 (+ AAC if audio kept).
 */
export function buildEditFfmpegArgs(opts: {
  inputPath: string;
  outputPath: string;
  probe: EditProbeMeta;
  plan: ResolvedEditPlan;
  /** Intermediate encode: keep timeline audio despite [plan.mute] (Whisper input before final mute). */
  keepAudioDespiteMute?: boolean;
}): BuiltEditFfmpeg {
  const { inputPath, outputPath, probe, plan, keepAudioDespiteMute } = opts;
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
    rotationDegrees: plan.rotationDegrees,
  });

  const filters: string[] = [vSpatial];
  /** Timeline audio after trim + speed; kept for Whisper when burning captions even if final export is muted. */
  const encodeTimelineAudio = probe.hasAudio && (!plan.mute || !!keepAudioDespiteMute);
  if (encodeTimelineAudio) {
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

  if (encodeTimelineAudio) {
    args.push("-map", "[aout]", "-c:a", "aac", "-b:a", "128k");
  } else {
    args.push("-an");
  }

  args.push("-movflags", "+faststart", outputPath);

  return { args, segmentDurationSec };
}

/**
 * Final pass: burn ASS (optional) + export codec + respect mute on **output** mux only.
 * Input is the sped/trimmed/formatted intermediate MP4 (`buildEditFfmpegArgs` `keepAudioDespiteMute` path).
 */
export function buildEditFinalEncodeAfterCaptionsArgs(opts: {
  intermediatePath: string;
  outputPath: string;
  plan: ResolvedEditPlan;
  /** Full `-vf` clause (e.g. `subtitles=/path/file.ass`). **Null** skips burn-in filter. */
  videoFilter: string | null;
  /** From ffprobe on the intermediate file */
  intermediateHasAudio: boolean;
  /** Output duration for ffmpeg progress parsing */
  timelineDurationSec: number;
}): BuiltEditFfmpeg {
  const { intermediatePath, outputPath, plan, videoFilter, intermediateHasAudio, timelineDurationSec } = opts;
  const { crf, presetName } = x264EncodeOpts(plan.compressPreset);

  const args: string[] = [
    "-hide_banner",
    "-nostats",
    "-y",
    "-i",
    intermediatePath,
    ...(videoFilter ? (["-vf", videoFilter] as const) : []),
    "-map",
    "0:v",
    "-c:v",
    "libx264",
    "-preset",
    presetName,
    "-crf",
    crf,
    "-pix_fmt",
    "yuv420p",
  ];

  if (!plan.mute && intermediateHasAudio) {
    args.push("-map", "0:a:0?", "-c:a", "aac", "-b:a", "128k");
  } else {
    args.push("-an");
  }

  args.push("-movflags", "+faststart", outputPath);
  return { args, segmentDurationSec: timelineDurationSec > 0 ? timelineDurationSec : 1 };
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
