import path from "node:path";

/** Escape path for ffmpeg filter arguments (Windows-safe). */
export function ffmpegEscapeFilterPath(absPath: string): string {
  const normalized = path.resolve(absPath).replace(/\\/g, "/");
  return `'${normalized.replace(/'/g, "'\\''")}'`;
}

const MAX_OVERLAY_INPUTS = 48;

/**
 * Build `-filter_complex` that overlays timed PNG plates on `[0:v]`.
 * Returns null when no plates.
 */
export function buildTimedOverlayFilterComplex(
  plates: readonly { readonly path: string; readonly startSec: number; readonly endSec: number }[],
): string | null {
  if (!plates.length) return null;
  if (plates.length > MAX_OVERLAY_INPUTS) {
    throw new Error(`caption overlay plate count ${plates.length} exceeds limit ${MAX_OVERLAY_INPUTS}`);
  }

  let chain = "[0:v]";
  for (let i = 0; i < plates.length; i++) {
    const p = plates[i]!;
    const inLabel = `[${i + 1}:v]`;
    const outLabel = i === plates.length - 1 ? "[vout]" : `[vx${i}]`;
    const t0 = Math.max(0, p.startSec).toFixed(3);
    const t1 = Math.max(0, p.endSec).toFixed(3);
    chain += `${inLabel}overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2:enable='between(t,${t0},${t1})'${outLabel};`;
  }
  return chain.replace(/;$/, "");
}

export function buildOverlayFfmpegInputArgs(
  plates: readonly { readonly path: string; readonly startSec: number; readonly endSec: number }[],
): string[] {
  const args: string[] = [];
  for (const p of plates) {
    args.push("-loop", "1", "-t", String(Math.max(0.05, p.endSec - p.startSec)), "-i", p.path);
  }
  return args;
}

export const CAPTION_OVERLAY_MAX_PLATES = MAX_OVERLAY_INPUTS;
