import type { CaptionsBurnInV1Resolved, CaptionsFontSize } from "../../modules/edit/edit.types";

/** Match ASS PlayRes for burn-in parity. */
export const CAPTION_PLAY_W = 960;
export const CAPTION_PLAY_H = 540;

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

export function captionFontSizePx(fontSize: CaptionsFontSize): number {
  return FONT_SIZES[fontSize];
}

export function captionMaxLineWidthPx(fontSize: CaptionsFontSize): number {
  const chars = MAX_CHARS_PER_LINE[fontSize];
  const px = captionFontSizePx(fontSize);
  return Math.min(CAPTION_PLAY_W - MARGIN_H * 2, Math.max(200, chars * px * 0.58));
}

/** Vertical anchor adjustment from offsetY (ASS parity). */
export function captionBlockTopBase(
  position: CaptionsBurnInV1Resolved["position"],
  blockHeight: number,
  offsetY: number,
): number {
  const oy = offsetY;
  if (position === "top") {
    let yRaw = Math.round(MARGIN_V + oy);
    const yLo = 38;
    const yHi = Math.floor(CAPTION_PLAY_H * 0.46);
    yRaw = Math.min(yHi, Math.max(yLo, yRaw));
    return yRaw;
  }
  let yRaw = Math.round(CAPTION_PLAY_H - MARGIN_V + oy);
  const yHi = CAPTION_PLAY_H - 38;
  const yLo = Math.ceil(CAPTION_PLAY_H * 0.54);
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
