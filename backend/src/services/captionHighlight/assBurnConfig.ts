import type { CaptionsBurnInV1Resolved } from "../../modules/edit/edit.types";

/**
 * Config for ASS/libass burn-in. Production must never pass color/box here —
 * inline word highlight is deprecated (use canvas overlay or static captions).
 */
export function captionsConfigForAssBurn(cfg: CaptionsBurnInV1Resolved): CaptionsBurnInV1Resolved {
  if (cfg.wordHighlight === "none") return cfg;
  return { ...cfg, wordHighlight: "none" };
}
