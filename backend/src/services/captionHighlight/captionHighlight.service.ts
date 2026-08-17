import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import type { CaptionsBurnInV1Resolved, CaptionCueWordResolved } from "../../modules/edit/edit.types";
import type { TranscriptSegment } from "../transcription.service";
import { chunkSegmentForHighlight } from "./chunk";
import { resolveHighlightStyle } from "./colors";
import {
  type CaptionCanvasSize,
  captionFontSizePx,
  captionFontWeight,
  captionMaxLineWidthPx,
  resolveCaptionCanvasSize,
} from "./dimensions";
import { renderCaptionHighlightPlate } from "./renderPlate";
import { assertHighlightPlatesVisible } from "./plateInspect";
import { alignWordsForChunk, resolveWordTimingCues } from "./timing";
import type { HighlightBurnPlan, RenderPlateInput, TimedPlate } from "./types";
import { resolveTextDirection } from "./tokenize";

function plateCacheKey(
  text: string,
  activeIndex: number,
  style: ReturnType<typeof resolveHighlightStyle>,
  cfg: CaptionsBurnInV1Resolved,
  canvas: CaptionCanvasSize,
): string {
  const h = createHash("sha256");
  h.update(text);
  h.update(String(activeIndex));
  h.update(style.normalCss);
  h.update(style.activeCss);
  h.update(style.boxCss);
  h.update(style.boxShape);
  h.update(String(style.drawBox));
  h.update(String(style.outlineEnabled));
  h.update(style.outlineCss);
  h.update(String(style.outlineWidthPx(captionFontSizePx(cfg.fontSize, canvas))));
  h.update(cfg.fontFamily);
  h.update(cfg.fontSize);
  h.update(cfg.position);
  h.update(String(cfg.offsetX));
  h.update(String(cfg.offsetY));
  h.update(String(canvas.width));
  h.update(String(canvas.height));
  return h.digest("hex").slice(0, 20);
}

function buildPlateInput(
  lines: readonly string[],
  activeWordIndex: number,
  cfg: CaptionsBurnInV1Resolved,
  style: ReturnType<typeof resolveHighlightStyle>,
  canvas: CaptionCanvasSize,
): RenderPlateInput {
  const displayText = lines.join(" ");
  return {
    lines: [...lines],
    text: displayText,
    activeWordIndex,
    direction: resolveTextDirection(displayText, "auto"),
    fontFamily: cfg.fontFamily,
    fontSize: captionFontSizePx(cfg.fontSize, canvas),
    fontWeight: captionFontWeight(cfg.style),
    normalTextColor: style.normalCss,
    activeTextColor: style.activeCss,
    boxColor: style.boxCss,
    boxShape: style.boxShape,
    drawBox: style.drawBox,
    maxLines: 2,
    canvasWidth: canvas.width,
    canvasHeight: canvas.height,
    position: cfg.position,
    maxLineWidthPx: captionMaxLineWidthPx(cfg.fontSize, canvas),
    lineGapPx: 10,
    // Gap is measured from font U+0020 in layoutCaptionBlock; value ignored.
    tokenGapPx: 0,
    boxPaddingXPx: 8,
    boxPaddingYPx: 5,
    offsetY: cfg.offsetY,
    outlineEnabled: style.outlineEnabled,
    outlineColorCss: style.outlineEnabled ? style.outlineCss : undefined,
    outlineWidthPx: style.outlineEnabled ? style.outlineWidthPx(captionFontSizePx(cfg.fontSize, canvas)) : undefined,
  };
}

export function usesCaptionHighlightOverlay(cfg: CaptionsBurnInV1Resolved): boolean {
  return cfg.wordHighlight === "color" || cfg.wordHighlight === "box";
}

/**
 * Render timed transparent PNG plates for word-highlight burn-in.
 */
export async function buildCaptionHighlightBurnPlan(
  segments: readonly TranscriptSegment[],
  cfg: CaptionsBurnInV1Resolved,
  workDir: string,
  video?: { width?: number; height?: number },
): Promise<HighlightBurnPlan> {
  await fs.mkdir(workDir, { recursive: true });

  const canvas = resolveCaptionCanvasSize(video);
  const style = resolveHighlightStyle(cfg);
  const plates: TimedPlate[] = [];
  const cache = new Map<string, string>();
  let wordCount = 0;
  let usedFallbackTiming = false;

  for (let si = 0; si < segments.length; si++) {
    const seg = segments[si]!;
    const chunks = chunkSegmentForHighlight(seg.text, seg.startSec, seg.endSec, cfg.fontSize);
    const wordsPayload: readonly CaptionCueWordResolved[] | undefined = Array.isArray(seg.words)
      ? seg.words.map((w) => ({
          startSec: w.startSec,
          endSec: w.endSec,
          text: w.text,
        }))
      : undefined;

    for (let ci = 0; ci < chunks.length; ci++) {
      const chunk = chunks[ci]!;
      const chunkWords = alignWordsForChunk(chunk.text, chunk.startSec, chunk.endSec, wordsPayload);
      const { cues, usedFallback } = resolveWordTimingCues(
        chunk.text,
        seg.startSec,
        seg.endSec,
        chunk.startSec,
        chunk.endSec,
        chunkWords,
      );
      usedFallbackTiming = usedFallbackTiming || usedFallback;

      for (let wi = 0; wi < cues.length; wi++) {
        const cue = cues[wi]!;
        const next = cues[wi + 1];
        const t0 = Math.max(chunk.startSec, cue.startSec);
        const t1 = Math.min(chunk.endSec, next ? next.startSec : cue.endSec);
        if (!(t1 > t0 + 1e-4)) continue;

        const key = plateCacheKey(chunk.text, cue.activeWordIndex, style, cfg, canvas);
        let platePath = cache.get(key);
        if (!platePath) {
          const input = buildPlateInput(chunk.lines, cue.activeWordIndex, cfg, style, canvas);
          const rendered = await renderCaptionHighlightPlate(input);
          if (rendered.activeTokenCount !== 1) {
            throw new Error(
              `caption highlight plate activeTokenCount=${rendered.activeTokenCount} (expected 1)`,
            );
          }
          platePath = path.join(workDir, `plate-${plates.length.toString().padStart(5, "0")}-${key}.png`);
          await fs.writeFile(platePath, rendered.png);
          cache.set(key, platePath);
        }

        plates.push({
          startSec: t0,
          endSec: t1,
          platePath,
          activeWordIndex: cue.activeWordIndex,
        });
        wordCount += 1;
      }
    }
  }

  if (!plates.length) {
    throw new Error("caption_highlight_no_plates");
  }

  await assertHighlightPlatesVisible([...cache.values()]);

  return {
    plates,
    plateCount: plates.length,
    wordCount,
    usedFallbackTiming,
    canvasWidth: canvas.width,
    canvasHeight: canvas.height,
  };
}
