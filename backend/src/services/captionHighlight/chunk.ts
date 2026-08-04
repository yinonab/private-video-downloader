import type { CaptionsFontSize } from "../../modules/edit/edit.types";
import { CAPTION_MAX_CHARS_PER_LINE } from "./dimensions";
import { normalizeCaptionText } from "./tokenize";
import { breakCaptionLines } from "../captionLineBreak";

const MIN_VISIBLE_CHUNK_DURATION_SEC = 0.85;
const MIN_CHUNK_DURATION_SEC = 0.16;

export type TextTimeChunk = {
  /** Forced logical lines from the shared line-break SoT (1–2 per timed event). */
  readonly lines: readonly string[];
  /** Same lines joined with `\n` (timing/align; not a second wrap source). */
  readonly text: string;
  readonly startSec: number;
  readonly endSec: number;
};

/**
 * Split segment into timed text chunks (≤2 lines per chunk).
 * Line breaks come only from `breakCaptionLines` (shared SoT).
 */
export function chunkSegmentForHighlight(
  text: string,
  startSec: number,
  endSec: number,
  fontSize: CaptionsFontSize,
): TextTimeChunk[] {
  const plain = normalizeCaptionText(text);
  if (!plain.length) return [];

  let start = Number.isFinite(startSec) && startSec >= 0 ? startSec : 0;
  let end = Number.isFinite(endSec) ? endSec : start + MIN_CHUNK_DURATION_SEC * 8;
  if (!(end > start)) end = start + Math.max(MIN_CHUNK_DURATION_SEC, 0.2);
  const dur = end - start;

  let maxChars = Math.max(8, CAPTION_MAX_CHARS_PER_LINE[fontSize]);

  const buildChunks = (): string[][] => {
    const wrappedLines = breakCaptionLines(plain, maxChars);
    const chunks: string[][] = [];
    for (let i = 0; i < wrappedLines.length; i += 2) {
      const line1 = wrappedLines[i] ?? "";
      const line2 = wrappedLines[i + 1];
      const lines = line2?.trim().length ? [line1, line2] : [line1];
      if (lines.some((l) => l.length > 0)) chunks.push(lines);
    }
    return chunks;
  };

  let lineChunks = buildChunks();
  while (lineChunks.length > 1) {
    const per = dur / lineChunks.length;
    if (per >= MIN_VISIBLE_CHUNK_DURATION_SEC || maxChars >= 48 + CAPTION_MAX_CHARS_PER_LINE[fontSize]) {
      break;
    }
    maxChars += 2;
    lineChunks = buildChunks();
  }
  while (
    lineChunks.length > 1 &&
    dur / lineChunks.length < MIN_VISIBLE_CHUNK_DURATION_SEC &&
    maxChars < 96
  ) {
    maxChars += 2;
    lineChunks = buildChunks();
  }

  if (!lineChunks.length) return [];
  const k = lineChunks.length;
  const out: TextTimeChunk[] = [];
  for (let i = 0; i < k; i++) {
    const t0 = start + (dur * i) / k;
    const t1 = i === k - 1 ? end : start + (dur * (i + 1)) / k;
    const lines = lineChunks[i]!;
    out.push({
      lines,
      text: lines.join("\n"),
      startSec: t0,
      endSec: t1,
    });
  }
  return out;
}
