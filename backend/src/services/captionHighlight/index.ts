export type { HighlightBurnPlan, TimedPlate } from "./types";
export { usesCaptionHighlightOverlay, buildCaptionHighlightBurnPlan } from "./captionHighlight.service";
export { captionsConfigForAssBurn } from "./assBurnConfig";
export {
  buildCaptionHighlightAlphaVideo,
  CAPTION_ALPHA_OVERLAY_FILTER,
  CAPTION_ALPHA_VIDEO_CODEC,
  CAPTION_ALPHA_VIDEO_PIX_FMT,
  type AlphaVideoBuildResult,
} from "./alphaVideo";
export { inspectCaptionPlate, assertHighlightPlatesVisible, type PlateInspection } from "./plateInspect";
export {
  buildTimedOverlayFilterComplex,
  buildOverlayFfmpegInputArgs,
  validateOverlayFilterComplex,
  CAPTION_OVERLAY_MAX_PLATES,
  type OverlayFilterBuild,
} from "./ffmpegOverlay";
export { resolveCaptionCanvasSize, CAPTION_PLAY_W, CAPTION_PLAY_H } from "./dimensions";
export { resolveHighlightStyle, textColorToCss } from "./colors";
export { renderCaptionHighlightPlate } from "./renderPlate";
export { tokenizeCaptionText, resolveTextDirection } from "./tokenize";
export { resolveWordTimingCues, alignWordsForChunk } from "./timing";
