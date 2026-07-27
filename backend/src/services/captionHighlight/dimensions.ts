import type { CaptionsBurnInV1Resolved, CaptionsFontSize } from "../../modules/edit/edit.types";

/**
 * Shared caption layout policy (PlayRes reference).
 * Preview (Flutter) and burn-in (ASS / highlight canvas) should track these ratios.
 */
export const CAPTION_PLAY_W = 960;
export const CAPTION_PLAY_H = 540;

/** Horizontal safe margin in PlayRes px (each side). */
export const CAPTION_MARGIN_H = 52;
/** Vertical safe margin in PlayRes px. */
export const CAPTION_MARGIN_V = 96;

/**
 * Soft wrap budgets for ASS `\N` / highlight chunking (code points).
 * Tuned so typical Hebrew phrases keep multiple words per line (not one-word stacks).
 */
export const CAPTION_MAX_CHARS_PER_LINE: Record<CaptionsFontSize, number> = {
  extra_small: 42,
  small: 38,
  medium: 34,
  large: 28,
  x_large: 24,
  xx_large: 20,
};

export type CaptionCanvasSize = {
  readonly width: number;
  readonly height: number;
};

const FONT_SIZES: Record<CaptionsFontSize, number> = {
  extra_small: 16,
  small: 20,
  medium: 24,
  large: 30,
  x_large: 36,
  xx_large: 44,
};

/** Resolve burn canvas from ffprobe video stream (fallback to PlayRes for tests). */
export function resolveCaptionCanvasSize(video?: { width?: number; height?: number }): CaptionCanvasSize {
  const w = video?.width;
  const h = video?.height;
  if (typeof w === "number" && typeof h === "number" && w > 0 && h > 0 && Number.isFinite(w + h)) {
    return { width: Math.round(w), height: Math.round(h) };
  }
  return { width: CAPTION_PLAY_W, height: CAPTION_PLAY_H };
}

function scaleFromPlayRes(canvas: CaptionCanvasSize): { sx: number; sy: number } {
  return {
    sx: canvas.width / CAPTION_PLAY_W,
    sy: canvas.height / CAPTION_PLAY_H,
  };
}

/**
 * Uniform scale (min of axes) so portrait video does not inflate fonts by height alone —
 * that previously forced ~1 Hebrew word per line at large sizes on 9:16 canvases.
 */
export function captionUniformScale(canvas: CaptionCanvasSize): number {
  const { sx, sy } = scaleFromPlayRes(canvas);
  return Math.min(sx, sy);
}

export function captionFontSizePx(fontSize: CaptionsFontSize, canvas: CaptionCanvasSize): number {
  const base = FONT_SIZES[fontSize];
  return Math.max(12, Math.round(base * captionUniformScale(canvas)));
}

/**
 * Max line width = video safe area (full width minus scaled horizontal margins).
 * Avoids Latin-centric `chars × glyph` estimates that were too narrow on landscape
 * and still left portrait large fonts stacking single words.
 */
export function captionMaxLineWidthPx(_fontSize: CaptionsFontSize, canvas: CaptionCanvasSize): number {
  const { sx } = scaleFromPlayRes(canvas);
  const marginH = Math.round(CAPTION_MARGIN_H * sx);
  const safe = canvas.width - marginH * 2;
  return Math.max(200, safe);
}

/** Vertical anchor adjustment from offsetY (scaled to canvas height). */
export function captionBlockTopBase(
  position: CaptionsBurnInV1Resolved["position"],
  blockHeight: number,
  offsetY: number,
  canvas: CaptionCanvasSize,
): number {
  const { sy } = scaleFromPlayRes(canvas);
  const marginV = Math.round(CAPTION_MARGIN_V * sy);
  const oy = Math.round(offsetY * sy);

  if (position === "top") {
    let yRaw = Math.round(marginV + oy);
    const yLo = Math.round(38 * sy);
    const yHi = Math.floor(canvas.height * 0.46);
    yRaw = Math.min(yHi, Math.max(yLo, yRaw));
    return yRaw;
  }
  let yRaw = Math.round(canvas.height - marginV + oy);
  const yHi = canvas.height - Math.round(38 * sy);
  const yLo = Math.ceil(canvas.height * 0.54);
  yRaw = Math.min(yHi, Math.max(yLo, yRaw));
  return yRaw - blockHeight;
}

export function captionFontWeight(style: CaptionsBurnInV1Resolved["style"]): number {
  switch (style) {
    case "bold":
    case "bold_social":
    case "yellow_headline":
    case "highlight_box":
      return 700;
    default:
      return 600;
  }
}
