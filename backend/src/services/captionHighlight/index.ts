export type { HighlightBurnPlan, TimedPlate } from "./types";
export { usesCaptionHighlightOverlay, buildCaptionHighlightBurnPlan } from "./captionHighlight.service";
export { captionsConfigForAssBurn } from "./assBurnConfig";
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
export { resolveWordTimingCues } from "./timing";
