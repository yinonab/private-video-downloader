import type {
  CaptionsBurnInV1Resolved,
  CaptionsTextColor,
  CaptionsWordHighlight,
} from "../../modules/edit/edit.types";
import type { BoxShape, ResolvedHighlightStyle } from "./types";

/** CSS colors for canvas fill (opaque). */
export function textColorToCss(color: CaptionsTextColor): string {
  switch (color) {
    case "yellow":
      return "#FFD966";
    case "purple":
      return "#F65C8B";
    case "mint":
      return "#99D334";
    case "black":
      return "#101010";
    case "white":
    default:
      return "#FFFFFF";
  }
}

export function boxColorToCss(color: CaptionsTextColor, alpha = 0.88): string {
  const base = textColorToCss(color);
  if (base.startsWith("#") && base.length === 7) {
    const r = parseInt(base.slice(1, 3), 16);
    const g = parseInt(base.slice(3, 5), 16);
    const b = parseInt(base.slice(5, 7), 16);
    return `rgba(${r},${g},${b},${alpha})`;
  }
  return base;
}

function contrastingTextForBox(box: CaptionsTextColor): CaptionsTextColor {
  return box === "yellow" || box === "mint" ? "black" : "white";
}

function defaultActiveTextColor(
  wordHighlight: CaptionsWordHighlight,
  normal: CaptionsTextColor,
  box: CaptionsTextColor,
): CaptionsTextColor {
  if (wordHighlight === "box") {
    return contrastingTextForBox(box);
  }
  if (normal === "yellow") return "purple";
  if (normal === "white") return "yellow";
  return "yellow";
}

function defaultBoxColor(color: CaptionsTextColor, wordHighlight: CaptionsWordHighlight): CaptionsTextColor {
  if (wordHighlight !== "box") return "yellow";
  if (color === "purple") return "purple";
  if (color === "mint") return "mint";
  return "yellow";
}

export function resolveHighlightStyle(cfg: CaptionsBurnInV1Resolved): ResolvedHighlightStyle {
  const normal = cfg.normalTextColor ?? cfg.color;
  const box = cfg.boxColor ?? defaultBoxColor(cfg.color, cfg.wordHighlight);
  const active =
    cfg.activeTextColor ?? defaultActiveTextColor(cfg.wordHighlight, normal, box);
  const boxShape: BoxShape = cfg.boxShape ?? "pill";

  return {
    normalCss: textColorToCss(normal),
    activeCss: textColorToCss(active),
    boxCss: boxColorToCss(box),
    boxShape,
    drawBox: cfg.wordHighlight === "box",
    wordHighlight: cfg.wordHighlight,
  };
}
