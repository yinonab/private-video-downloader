import type { CaptionCueWordResolved } from "../../modules/edit/edit.types";
import { normalizeCaptionText, tokenizeCaptionText } from "./tokenize";

export type WordTimingCue = {
  readonly startSec: number;
  readonly endSec: number;
  readonly activeWordIndex: number;
};

function approximateWordTimings(
  tokenCount: number,
  sliceStart: number,
  sliceEnd: number,
): WordTimingCue[] {
  if (tokenCount <= 0) return [];
  const dur = Math.max(1e-4, sliceEnd - sliceStart);
  const out: WordTimingCue[] = [];
  for (let i = 0; i < tokenCount; i++) {
    const t0 = sliceStart + (dur * i) / tokenCount;
    const t1 = i === tokenCount - 1 ? sliceEnd : sliceStart + (dur * (i + 1)) / tokenCount;
    out.push({ startSec: t0, endSec: t1, activeWordIndex: i });
  }
  return out;
}

function normalizePayloadWords(
  words: readonly CaptionCueWordResolved[] | undefined,
): { startSec: number; endSec: number; word: string }[] | undefined {
  if (!words?.length) return undefined;
  const out = words
    .map((w) => ({
      startSec: Number.isFinite(w.startSec) ? w.startSec : Number.NaN,
      endSec: Number.isFinite(w.endSec) ? w.endSec : Number.NaN,
      word: normalizeCaptionText(w.text),
    }))
    .filter((w) => Number.isFinite(w.startSec) && Number.isFinite(w.endSec) && w.endSec > w.startSec && w.word.length > 0);
  return out.length ? out : undefined;
}

/**
 * Token-index timing for overlay plates (no ASS string regex).
 */
export function resolveWordTimingCues(
  segmentText: string,
  segmentStartSec: number,
  segmentEndSec: number,
  sliceStart: number,
  sliceEnd: number,
  payloadWords: readonly CaptionCueWordResolved[] | undefined,
): { cues: WordTimingCue[]; usedFallback: boolean } {
  const tokens = tokenizeCaptionText(segmentText);
  if (tokens.length < 1) return { cues: [], usedFallback: false };

  const displayWords = tokens.map((t) => t.text);
  const fromPayload = normalizePayloadWords(payloadWords);

  if (!fromPayload?.length) {
    return {
      cues: approximateWordTimings(displayWords.length, sliceStart, sliceEnd),
      usedFallback: true,
    };
  }

  const payloadNormalized = fromPayload.map((w) => w.word);
  const canReuse =
    payloadNormalized.length === displayWords.length &&
    payloadNormalized.every((w, i) => w === displayWords[i]);

  if (!canReuse) {
    return {
      cues: approximateWordTimings(displayWords.length, sliceStart, sliceEnd),
      usedFallback: true,
    };
  }

  const minStart = fromPayload[0]!.startSec;
  const maxEnd = fromPayload[fromPayload.length - 1]!.endSec;
  const srcDur = Math.max(1e-4, maxEnd - minStart);
  const dstDur = Math.max(1e-4, segmentEndSec - segmentStartSec);

  const cues: WordTimingCue[] = [];
  for (let i = 0; i < fromPayload.length; i++) {
    const w = fromPayload[i]!;
    const stNorm = (w.startSec - minStart) / srcDur;
    const enNorm = (w.endSec - minStart) / srcDur;
    let st = segmentStartSec + stNorm * dstDur;
    let en = segmentStartSec + enNorm * dstDur;
    st = Math.max(segmentStartSec, Math.min(segmentEndSec, st));
    en = Math.max(segmentStartSec, Math.min(segmentEndSec, en));
    st = Math.max(sliceStart, Math.min(sliceEnd, st));
    en = Math.max(sliceStart, Math.min(sliceEnd, en));
    if (en <= st + 1e-4) continue;
    cues.push({ startSec: st, endSec: en, activeWordIndex: i });
  }

  if (!cues.length) {
    return {
      cues: approximateWordTimings(displayWords.length, sliceStart, sliceEnd),
      usedFallback: true,
    };
  }

  return { cues, usedFallback: false };
}
