import fs from "node:fs/promises";

import { AppError, codes } from "../types/errors";
import { logger } from "./logger";

export type TranscriptSegment = {
  startSec: number;
  endSec: number;
  text: string;
};

type VerboseSegment = {
  start?: unknown;
  end?: unknown;
  text?: unknown;
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
    res = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: { Authorization: `Bearer ${opts.apiKey}` },
      body: fd,
    });
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
  for (const s of segmentsRaw) {
    const row = s as VerboseSegment;
    const started = typeof row.start === "number" ? row.start : Number.NaN;
    const ended = typeof row.end === "number" ? row.end : Number.NaN;
    const txt = typeof row.text === "string" ? row.text.trim() : "";
    if (!Number.isFinite(started) || !Number.isFinite(ended)) continue;
    if (ended <= started) continue;
    if (txt.length === 0) continue;
    out.push({ startSec: started, endSec: ended, text: txt });
  }

  logger.info(
    { editJobId: opts.editJobId, model: opts.model, segmentCount: out.length, durationSec: durationKnown },
    "openai transcription completed"
  );
  return { segments: out, durationSec: durationKnown };
}
