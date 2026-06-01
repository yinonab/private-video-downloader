import fs from "node:fs/promises";

import { AppError, codes } from "../types/errors";
import { logger } from "./logger";

export type TranscriptSegment = {
  startSec: number;
  endSec: number;
  text: string;
  words?: readonly TranscriptWord[];
};

export type TranscriptWord = {
  startSec: number;
  endSec: number;
  text: string;
};

type VerboseSegment = {
  start?: unknown;
  end?: unknown;
  text?: unknown;
  words?: unknown;
};

type VerbosePayload = {
  duration?: unknown;
  segments?: unknown;
};

/**
 * Whisper-compatible transcription (`response_format` `verbose_json`) → normalized cues.
 *
 * Logs **`editJobId`**, **`model`**, **`durationSec`**, **`segmentCount`** only (never transcript text).
 */
export async function transcribeAudioFile(opts: {
  audioPath: string;
  apiKey: string;
  model: string;
  editJobId?: string;
}): Promise<{ segments: TranscriptSegment[]; durationSec?: number }> {
  const buf = await fs.readFile(opts.audioPath);
  const base = opts.audioPath.split(/[/\\]/).pop() ?? `captions.wav`;
  const fd = new FormData();
  fd.append("file", new Blob([buf], { type: "audio/wav" }), base);
  fd.append("model", opts.model);
  fd.append("response_format", "verbose_json");

  let res: Response;
  try {
    fd.append("timestamp_granularities[]", "segment");
    fd.append("timestamp_granularities[]", "word");
    res = await fetchTranscription(fd, opts.apiKey);
  } catch (e) {
    logger.warn({ editJobId: opts.editJobId, model: opts.model, err: String(e) }, "openai transcription network error");
    throw new AppError(codes.CAPTIONS_GENERATION_FAILED, "Transcription failed (network)", 503);
  }

  let bodyText = "";
  try {
    bodyText = await res.text();
  } catch {
    bodyText = "";
  }

  if (!res.ok && res.status === 400) {
    /** Keep existing model behavior stable: retry without word timestamp request if provider rejects it. */
    const fdFallback = new FormData();
    fdFallback.append("file", new Blob([buf], { type: "audio/wav" }), base);
    fdFallback.append("model", opts.model);
    fdFallback.append("response_format", "verbose_json");
    try {
      res = await fetchTranscription(fdFallback, opts.apiKey);
      bodyText = await res.text();
    } catch (e) {
      logger.warn({ editJobId: opts.editJobId, model: opts.model, err: String(e) }, "openai transcription network error");
      throw new AppError(codes.CAPTIONS_GENERATION_FAILED, "Transcription failed (network)", 503);
    }
  }

  if (!res.ok) {
    logger.warn(
      {
        editJobId: opts.editJobId,
        httpStatus: res.status,
        model: opts.model,
      },
      "openai transcription non-OK"
    );
    throw new AppError(
      codes.CAPTIONS_GENERATION_FAILED,
      "Transcription service returned an error",
      res.status >= 500 ? 503 : 400
    );
  }

  let payload: unknown;
  try {
    payload = JSON.parse(bodyText);
  } catch {
    logger.warn({ editJobId: opts.editJobId, model: opts.model }, "openai transcription JSON parse failure");
    throw new AppError(codes.CAPTIONS_GENERATION_FAILED, "Invalid transcription response", 502);
  }

  const v = payload as VerbosePayload;
  const segmentsRaw = v.segments;
  const durationKnown = typeof v.duration === "number" && Number.isFinite(v.duration) ? v.duration : undefined;

  if (!Array.isArray(segmentsRaw)) {
    logger.warn({ editJobId: opts.editJobId, model: opts.model, durationSec: durationKnown }, "openai transcription missing segments array");
    return { segments: [], durationSec: durationKnown };
  }

  const out: TranscriptSegment[] = [];
  let wordCount = 0;
  for (const s of segmentsRaw) {
    const row = s as VerboseSegment;
    const started = typeof row.start === "number" ? row.start : Number.NaN;
    const ended = typeof row.end === "number" ? row.end : Number.NaN;
    const txt = typeof row.text === "string" ? row.text.trim() : "";
    if (!Number.isFinite(started) || !Number.isFinite(ended)) continue;
    if (ended <= started) continue;
    if (txt.length === 0) continue;
    const words = parseWordsFromUnknown(row.words, started, ended);
    if (words?.length) wordCount += words.length;
    out.push({ startSec: started, endSec: ended, text: txt, words });
  }

  logger.info(
    {
      editJobId: opts.editJobId,
      model: opts.model,
      segmentCount: out.length,
      wordCount,
      hasWordTimestamps: wordCount > 0,
      durationSec: durationKnown,
    },
    "openai transcription completed"
  );
  return { segments: out, durationSec: durationKnown };
}

async function fetchTranscription(fd: FormData, apiKey: string): Promise<Response> {
  return fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: fd,
  });
}

function parseWordsFromUnknown(raw: unknown, segStart: number, segEnd: number): TranscriptWord[] | undefined {
  if (!Array.isArray(raw)) return undefined;
  const out: TranscriptWord[] = [];
  for (const row of raw) {
    if (row == null || typeof row !== "object") continue;
    const w = row as { start?: unknown; end?: unknown; word?: unknown; text?: unknown };
    const startSec = typeof w.start === "number" ? w.start : Number.NaN;
    const endSec = typeof w.end === "number" ? w.end : Number.NaN;
    const text = typeof w.word === "string" ? w.word.trim() : typeof w.text === "string" ? w.text.trim() : "";
    if (!Number.isFinite(startSec) || !Number.isFinite(endSec)) continue;
    if (!(endSec > startSec) || text.length === 0) continue;
    const st = Math.max(segStart, Math.min(segEnd, startSec));
    const en = Math.max(st, Math.min(segEnd, endSec));
    if (en <= st + 1e-4) continue;
    out.push({ startSec: st, endSec: en, text });
  }
  return out.length ? out : undefined;
}
