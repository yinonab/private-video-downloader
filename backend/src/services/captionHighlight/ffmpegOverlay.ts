/** Max PNG overlay inputs per final encode (command-line / filter graph practical limit). */
export const CAPTION_OVERLAY_MAX_PLATES = 400;

export type TimedOverlayPlate = {
  readonly path: string;
  readonly startSec: number;
  readonly endSec: number;
};

export type OverlayFilterBuild = {
  readonly filter: string;
  readonly segmentCount: number;
  readonly plateCount: number;
};

/**
 * Build labeled `-filter_complex` overlay chain:
 * `[0:v][1:v]overlay...[vx0];[vx0][2:v]overlay...[vx1];…[vout]`
 */
export function buildTimedOverlayFilterComplex(
  plates: readonly TimedOverlayPlate[],
): OverlayFilterBuild | null {
  if (!plates.length) return null;
  if (plates.length > CAPTION_OVERLAY_MAX_PLATES) {
    throw new Error(`caption overlay plate count ${plates.length} exceeds limit ${CAPTION_OVERLAY_MAX_PLATES}`);
  }

  const parts: string[] = [];
  let prev = "0:v";

  for (let i = 0; i < plates.length; i++) {
    const p = plates[i]!;
    const overlayIn = `${i + 1}:v`;
    const out = i === plates.length - 1 ? "vout" : `vx${i}`;
    const t0 = Math.max(0, p.startSec).toFixed(3);
    const t1 = Math.max(0, p.endSec).toFixed(3);
    parts.push(
      `[${prev}][${overlayIn}]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2:enable='between(t,${t0},${t1})'[${out}]`,
    );
    prev = out;
  }

  return {
    filter: parts.join(";"),
    segmentCount: parts.length,
    plateCount: plates.length,
  };
}

/** Structural validation for diagnostics (every segment must chain labeled pads). */
export function validateOverlayFilterComplex(build: OverlayFilterBuild): void {
  const { filter, segmentCount, plateCount } = build;
  if (segmentCount !== plateCount) {
    throw new Error(`overlay filter segmentCount ${segmentCount} !== plateCount ${plateCount}`);
  }
  if (!filter.includes("[vout]")) {
    throw new Error("overlay filter missing [vout]");
  }
  if (plateCount === 1) {
    if (!filter.startsWith("[0:v][1:v]overlay")) {
      throw new Error("single-plate filter must start with [0:v][1:v]overlay");
    }
    return;
  }
  for (let i = 0; i < plateCount - 1; i++) {
    const need = `[vx${i}][${i + 2}:v]overlay`;
    if (!filter.includes(need)) {
      throw new Error(`overlay filter missing chained segment ${need}`);
    }
  }
}

export function buildOverlayFfmpegInputArgs(plates: readonly TimedOverlayPlate[]): string[] {
  const args: string[] = [];
  for (const p of plates) {
    const dur = Math.max(0.05, p.endSec - p.startSec);
    args.push("-f", "image2", "-loop", "1", "-t", String(dur), "-i", p.path);
  }
  return args;
}
