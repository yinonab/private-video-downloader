export type { HighlightBurnPlan, TimedPlate } from "./types";
export { usesCaptionHighlightOverlay, buildCaptionHighlightBurnPlan } from "./captionHighlight.service";
export { captionsConfigForAssBurn } from "./assBurnConfig";
export {
  buildCaptionHighlightAlphaVideo,
  CAPTION_ALPHA_OVERLAY_FILTER,
  CAPTION_ALPHA_VIDEO_CODEC,
  CAPTION_ALPHA_VIDEO_PIX_FMT,
  CAPTION_ALPHA_VIDEO_EXT,
  type AlphaVideoBuildResult,
} from "./alphaVideo";
export { resolveHighlightStyle, textColorToCss, boxColorToCss } from "./colors";
export { inspectCaptionPlate, assertHighlightPlatesVisible, type PlateInspection } from "./plateInspect";
export {
  buildTimedOverlayFilterComplex,
  buildOverlayFfmpegInputArgs,
  validateOverlayFilterComplex,
  CAPTION_OVERLAY_MAX_PLATES,
  type OverlayFilterBuild,
} from "./ffmpegOverlay";
export { resolveCaptionCanvasSize, CAPTION_PLAY_W, CAPTION_PLAY_H, CAPTION_MARGIN_H, CAPTION_MAX_CHARS_PER_LINE, captionFontSizePx, captionMaxLineWidthPx } from "./dimensions";
export { renderCaptionHighlightPlate, highlightPlateBoxFromBaseline } from "./renderPlate";
export { breakCaptionLines, breakCaptionLinesForFontSize, scoreTwoLineCaption } from "../captionLineBreak";
export { chunkSegmentForHighlight } from "./chunk";
export { tokenizeCaptionText, resolveTextDirection, captionTokenDisplayText, captionTokenMatchesWord } from "./tokenize";
export { resolveWordTimingCues, alignWordsForChunk } from "./timing";
