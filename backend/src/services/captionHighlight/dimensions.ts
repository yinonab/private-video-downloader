import type { CaptionsBurnInV1Resolved, CaptionsFontSize } from "../../modules/edit/edit.types";

/** PoC / ASS script reference resolution only — production uses probed video size. */
export const CAPTION_PLAY_W = 960;
export const CAPTION_PLAY_H = 540;

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

const MAX_CHARS_PER_LINE: Record<CaptionsFontSize, number> = {
  extra_small: 32,
  small: 28,
  medium: 24,
  large: 20,
  x_large: 16,
  xx_large: 14,
};

const MARGIN_H = 52;
const MARGIN_V = 96;

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

export function captionFontSizePx(fontSize: CaptionsFontSize, canvas: CaptionCanvasSize): number {
  const base = FONT_SIZES[fontSize];
  const { sy } = scaleFromPlayRes(canvas);
  return Math.max(12, Math.round(base * sy));
}

export function captionMaxLineWidthPx(fontSize: CaptionsFontSize, canvas: CaptionCanvasSize): number {
  const chars = MAX_CHARS_PER_LINE[fontSize];
  const px = captionFontSizePx(fontSize, canvas);
  const { sx } = scaleFromPlayRes(canvas);
  const marginH = Math.round(MARGIN_H * sx);
  return Math.min(canvas.width - marginH * 2, Math.max(200, Math.round(chars * px * 0.58)));
}

/** Vertical anchor adjustment from offsetY (scaled to canvas height). */
export function captionBlockTopBase(
  position: CaptionsBurnInV1Resolved["position"],
  blockHeight: number,
  offsetY: number,
  canvas: CaptionCanvasSize,
): number {
  const { sy } = scaleFromPlayRes(canvas);
  const marginV = Math.round(MARGIN_V * sy);
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
