import type { CaptionsFontSize } from "../modules/edit/edit.types";
import { CAPTION_MAX_CHARS_PER_LINE } from "./captionHighlight/dimensions";

/**
 * Backend/export Source of Truth for caption line breaks.
 *
 * - One-line cues unchanged when they fit `maxChars`.
 * - When ≥1 valid two-line split exists: enumerate splits, score, pick lowest score.
 * - Otherwise: greedy + Unicode hard-split (oversized words, >2 lines, no valid 2-line pack).
 *
 * No timing, rendering, styling, baseline, plate, or ffmpeg logic.
 * Caller supplies already-normalized plain text (no ASS `\N`).
 */
export function breakCaptionLines(plainText: string, maxCharsPerLine: number): string[] {
  const maxChars = Math.max(1, Math.floor(maxCharsPerLine));
  const words = plainText.split(/\s+/).filter((w) => w.length > 0);
  if (!words.length) return [];

  const balanced = tryBalanceTwoLines(words, maxChars);
  if (balanced) return balanced;

  return greedyWordWrap(words, maxChars);
}

/** Convenience: size-table budget from `CAPTION_MAX_CHARS_PER_LINE`. */
export function breakCaptionLinesForFontSize(
  plainText: string,
  fontSize: CaptionsFontSize,
): string[] {
  return breakCaptionLines(plainText, CAPTION_MAX_CHARS_PER_LINE[fontSize]);
}

function unicodeLen(s: string): number {
  return [...s].length;
}

function joinWords(words: readonly string[]): string {
  return words.join(" ");
}

/**
 * v1 two-line score (lower is better). Char-width proxy only.
 *
 * imbalance + short-second + single-word orphan + tiny-first + weak comma break.
 */
export function scoreTwoLineCaption(line1: string, line2: string): number {
  const w1 = unicodeLen(line1);
  const w2 = unicodeLen(line2);
  const words1 = line1.split(/\s+/).filter((w) => w.length > 0).length;
  const words2 = line2.split(/\s+/).filter((w) => w.length > 0).length;

  const imbalance = Math.abs(w1 - w2);
  const shortSecondLinePenalty = Math.max(0, 0.5 * w1 - w2) * 2.5;
  const singleWordOrphanPenalty = words2 === 1 ? 4.0 : 0;
  const tinyFirstLinePenalty = words1 === 1 ? 2.0 : 0;
  const punctuationPenalty = /,$/u.test(line1.trim()) && words2 <= 2 ? 1.0 : 0;

  return (
    imbalance +
    shortSecondLinePenalty +
    singleWordOrphanPenalty +
    tinyFirstLinePenalty +
    punctuationPenalty
  );
}

/**
 * Returns balanced 1- or 2-line result, or `null` to fall back to greedy.
 * Null when any word exceeds maxChars (hard-split required) or no valid 2-line pack
 * exists and the cue does not fit on one line.
 */
function tryBalanceTwoLines(words: readonly string[], maxChars: number): string[] | null {
  if (words.some((w) => unicodeLen(w) > maxChars)) return null;

  const oneLine = joinWords(words);
  if (unicodeLen(oneLine) <= maxChars) return [oneLine];

  if (words.length < 2) return null;

  let bestLines: string[] | null = null;
  let bestScore = Number.POSITIVE_INFINITY;
  let bestSplit = Number.POSITIVE_INFINITY;

  for (let k = 1; k < words.length; k++) {
    const line1 = joinWords(words.slice(0, k));
    const line2 = joinWords(words.slice(k));
    if (unicodeLen(line1) > maxChars || unicodeLen(line2) > maxChars) continue;

    const score = scoreTwoLineCaption(line1, line2);
    // Deterministic: lower score wins; tie → earlier split index.
    if (score < bestScore || (score === bestScore && k < bestSplit)) {
      bestScore = score;
      bestSplit = k;
      bestLines = [line1, line2];
    }
  }

  return bestLines;
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

  const hardSplitUnits = (s: string, maxUnits: number): string[] => {
    const u = [...s];
    if (u.length <= maxUnits) return [s];
    const chunks: string[] = [];
    for (let i = 0; i < u.length; i += maxUnits) chunks.push(u.slice(i, i + maxUnits).join(""));
    return chunks;
  };

  const lineCharLen = (s: string): number => [...s].length;

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
