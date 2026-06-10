import type {
  CaptionsBurnInV1Resolved,
  CaptionsOutlineWidth,
  CaptionsTextColor,
} from "../modules/edit/edit.types";
import { textColorToCss } from "./captionHighlight/colors";

/** ASS outline width (PlayRes 960×540, ScaledBorderAndShadow=yes). */
export const OUTLINE_WIDTH_ASS: Record<CaptionsOutlineWidth, number> = {
  thin: 2.0,
  medium: 3.5,
  thick: 5.5,
};

/** ASS BGR opaque colour for caption text/outline tokens. */
export function textColorToAssColour(color: CaptionsTextColor): string {
  switch (color) {
    case "yellow":
      return "&H0066D9FF";
    case "purple":
      return "&H00F65C8B";
    case "pink":
      return "&H008A5CFF";
    case "mint":
      return "&H0099D334";
    case "black":
      return "&H00101010";
    case "white":
    default:
      return "&H00FFFFFF";
  }
}

export function outlineWidthCanvasPx(width: CaptionsOutlineWidth, fontSize: number): number {
  const scale = fontSize / 24;
  return OUTLINE_WIDTH_ASS[width] * scale;
}

export type ResolvedCaptionOutline = {
  readonly enabled: boolean;
  readonly color: CaptionsTextColor;
  readonly width: CaptionsOutlineWidth;
  readonly assColour: string;
  readonly assWidth: number;
  readonly css: string;
  readonly canvasWidthPx: (fontSize: number) => number;
};

export function resolveCaptionOutline(cfg: CaptionsBurnInV1Resolved): ResolvedCaptionOutline {
  const enabled = cfg.outlineEnabled === true;
  const color = cfg.outlineColor ?? "white";
  const width = cfg.outlineWidth ?? "medium";
  return {
    enabled,
    color,
    width,
    assColour: textColorToAssColour(color),
    assWidth: OUTLINE_WIDTH_ASS[width],
    css: textColorToCss(color),
    canvasWidthPx: (fontSize: number) => outlineWidthCanvasPx(width, fontSize),
  };
}
