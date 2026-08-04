import type { CaptionsFontSize } from "../modules/edit/edit.types";
import { CAPTION_MAX_CHARS_PER_LINE } from "./captionHighlight/dimensions";

/**
 * Backend/export Source of Truth for caption line breaks (Phase A).
 *
 * Pure composition: greedy Unicode char-budget wrap matching the former ASS
 * `greedyWordWrap` + `hardSplitUnits` behavior. No timing, rendering, styling,
 * baseline, plate, or ffmpeg logic.
 *
 * Caller supplies already-normalized plain text (no ASS `\N`).
 */
export function breakCaptionLines(plainText: string, maxCharsPerLine: number): string[] {
  const maxChars = Math.max(1, Math.floor(maxCharsPerLine));
  const words = plainText.split(/\s+/).filter((w) => w.length > 0);
  if (!words.length) return [];
  return greedyWordWrap(words, maxChars);
}

/** Convenience: size-table budget from `CAPTION_MAX_CHARS_PER_LINE`. */
export function breakCaptionLinesForFontSize(
  plainText: string,
  fontSize: CaptionsFontSize,
): string[] {
  return breakCaptionLines(plainText, CAPTION_MAX_CHARS_PER_LINE[fontSize]);
}

/** Greedy word wrap → lines (respect word boundaries when possible). Canonical ASS hard-split. */
function greedyWordWrap(words: readonly string[], maxChars: number): string[] {
  const linesOut: string[] = [];
  let cur = "";

  const flushLine = (): void => {
    const trimmed = cur.trim();
    if (trimmed.length) linesOut.push(trimmed);
    cur = "";
  };

  const pushWord = (w: string): void => {
    if (cur.length === 0) cur = w;
    else cur = `${cur} ${w}`;
  };

  const unitsOf = (s: string): string[] => [...s];

  const hardSplitUnits = (s: string, maxUnits: number): string[] => {
    const u = unitsOf(s);
    if (u.length <= maxUnits) return [s];
    const chunks: string[] = [];
    for (let i = 0; i < u.length; i += maxUnits) chunks.push(u.slice(i, i + maxUnits).join(""));
    return chunks;
  };

  const lineCharLen = (s: string): number => unitsOf(s).length;

  for (const w of words) {
    if (lineCharLen(w) > maxChars) {
      flushLine();
      const parts = hardSplitUnits(w, maxChars);
      for (let p = 0; p < parts.length; p++) {
        const piece = parts[p]!;
        if (lineCharLen(cur) === 0) pushWord(piece);
        else if (lineCharLen(cur) + 1 + lineCharLen(piece) <= maxChars) pushWord(piece);
        else {
          flushLine();
          pushWord(piece);
        }
        if (lineCharLen(cur) >= maxChars) flushLine();
      }
      continue;
    }

    if (cur.length === 0 || lineCharLen(cur) + 1 + lineCharLen(w) <= maxChars) pushWord(w);
    else {
      flushLine();
      pushWord(w);
    }
  }
  flushLine();
  return linesOut;
}
