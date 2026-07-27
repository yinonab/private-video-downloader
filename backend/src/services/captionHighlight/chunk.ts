import type { CaptionsFontSize } from "../../modules/edit/edit.types";
import { CAPTION_MAX_CHARS_PER_LINE } from "./dimensions";
import { normalizeCaptionText } from "./tokenize";

const MIN_VISIBLE_CHUNK_DURATION_SEC = 0.85;
const MIN_CHUNK_DURATION_SEC = 0.16;

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

  const lineCharLen = (s: string): number => [...s].length;

  for (const w of words) {
    if (lineCharLen(w) > maxChars) {
      flushLine();
      for (let i = 0; i < [...w].length; i += maxChars) {
        pushWord([...w].slice(i, i + maxChars).join(""));
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

export type TextTimeChunk = {
  readonly text: string;
  readonly startSec: number;
  readonly endSec: number;
};

/**
 * Split segment into timed text chunks (≤2 lines per chunk) — mirrors ASS segment chunking.
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

  const buildChunks = (): string[] => {
    const words = plain.split(/\s+/).filter((w) => w.length > 0);
    const wrappedLines = greedyWordWrap(words, maxChars);
    const chunks: string[] = [];
    for (let i = 0; i < wrappedLines.length; i += 2) {
      const line1 = wrappedLines[i] ?? "";
      const line2 = wrappedLines[i + 1];
      const dlg = line2?.trim().length ? `${line1}\n${line2}` : line1;
      if (dlg.length > 0) chunks.push(dlg);
    }
    return chunks;
  };

  let chunks = buildChunks();
  while (chunks.length > 1) {
    const per = dur / chunks.length;
    if (per >= MIN_VISIBLE_CHUNK_DURATION_SEC || maxChars >= 48 + CAPTION_MAX_CHARS_PER_LINE[fontSize]) break;
    maxChars += 2;
    chunks = buildChunks();
  }
  while (chunks.length > 1 && dur / chunks.length < MIN_VISIBLE_CHUNK_DURATION_SEC && maxChars < 96) {
    maxChars += 2;
    chunks = buildChunks();
  }

  if (!chunks.length) return [];
  const k = chunks.length;
  const out: TextTimeChunk[] = [];
  for (let i = 0; i < k; i++) {
    const t0 = start + (dur * i) / k;
    const t1 = i === k - 1 ? end : start + (dur * (i + 1)) / k;
    out.push({ text: chunks[i]!, startSec: t0, endSec: t1 });
  }
  return out;
}
