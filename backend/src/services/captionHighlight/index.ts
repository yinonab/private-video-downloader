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
export { resolveCaptionCanvasSize, CAPTION_PLAY_W, CAPTION_PLAY_H } from "./dimensions";
export { renderCaptionHighlightPlate } from "./renderPlate";
export { tokenizeCaptionText, resolveTextDirection, captionTokenDisplayText, captionTokenMatchesWord } from "./tokenize";
export { resolveWordTimingCues, alignWordsForChunk } from "./timing";
