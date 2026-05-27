import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import type { PrismaClient } from "@prisma/client";
import { config } from "../../config";
import { buildEditFfmpegArgs } from "./edit.ffmpeg";
import { captionsDraftRequestSchema, resolveEditOperations } from "./edit.schemas";
import { assertDownloadVideoSourceReady, assertUploadVideoSourceReady } from "./edit.service";
import { ffprobeMedia } from "../../services/ffmpegNormalize";
import { logger } from "../../services/logger";
import { ensureDeviceDirs, getEditsDir } from "../../services/storage";
import { transcribeAudioFile, type TranscriptSegment } from "../../services/transcription.service";
import { AppError, codes } from "../../types/errors";

const STDERR_CAP = 512_000;
const DRAFT_UNAVAIL_MSG = "Could not generate captions draft.";
const TMP_PREFIX = "cap-draft";

function runFfmpeg(args: string[], onStderr: (fullStderr: string) => void): Promise<number | null> {
  return new Promise((resolve) => {
    const child = spawn("ffmpeg", args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      if (stderr.length > STDERR_CAP) stderr = stderr.slice(-Math.floor(STDERR_CAP / 2));
      onStderr(stderr);
    });
    child.on("error", () => resolve(null));
    child.on("close", (code) => resolve(code));
  });
}

async function ffmpegExtractMonoWav16k(inputMp4: string, outputWav: string): Promise<number | null> {
  return runFfmpeg(
    [
      "-hide_banner",
      "-nostats",
      "-y",
      "-i",
      inputMp4,
      "-vn",
      "-ac",
      "1",
      "-ar",
      "16000",
      "-c:a",
      "pcm_s16le",
      "-f",
      "wav",
      outputWav,
    ],
    () => undefined
  );
}

/** POST /edits/captions/draft — Whisper on trim+speed adjusted timeline audio only (no burn-in). */
export async function generateCaptionsDraftForDevice(opts: {
  prisma: PrismaClient;
  deviceId: string;
  body: unknown;
}): Promise<{
  segments: readonly { readonly id: string; readonly startSec: number; readonly endSec: number; readonly text: string }[];
  durationSec: number;
  language: "auto";
}> {
  const parsed = captionsDraftRequestSchema.safeParse(opts.body);
  if (!parsed.success) {
    throw new AppError(codes.BAD_REQUEST, "Invalid body", 400);
  }
  const d = parsed.data;
  const hasDl = d.sourceDownloadJobId != null;
  const hasUp = d.sourceUploadId != null;
  if (!hasDl && !hasUp) {
    throw new AppError(
      codes.EDIT_SOURCE_REQUIRED,
      "Provide exactly one of sourceDownloadJobId or sourceUploadId",
      400
    );
  }
  if (hasDl && hasUp) {
    throw new AppError(codes.EDIT_MULTIPLE_SOURCES, "Provide only one of sourceDownloadJobId or sourceUploadId", 400);
  }
  if (!config.openaiApiKey.trim()) {
    throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 503);
  }

  let absPath: string;
  if (hasDl) {
    absPath = (
      await assertDownloadVideoSourceReady({
        prisma: opts.prisma,
        deviceId: opts.deviceId,
        sourceDownloadJobId: d.sourceDownloadJobId!,
      })
    ).absPath;
  } else {
    absPath = (
      await assertUploadVideoSourceReady({
        prisma: opts.prisma,
        deviceId: opts.deviceId,
        sourceUploadId: d.sourceUploadId!,
      })
    ).absPath;
  }

  let probe: Awaited<ReturnType<typeof ffprobeMedia>>;
  try {
    probe = await ffprobeMedia(absPath);
  } catch {
    throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 503);
  }

  const durationSecSrc = probe.durationMs > 0 ? probe.durationMs / 1000 : 0;
  if (!probe.video || durationSecSrc <= 0) {
    throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 400);
  }

  const plan = resolveEditOperations(d.operations ?? []);
  if (plan.trim != null && plan.trim.startSec >= durationSecSrc) {
    throw new AppError(codes.EDIT_INVALID_SOURCE, "Trim start is beyond video duration", 400);
  }

  await ensureDeviceDirs(opts.deviceId);
  const tmpId = randomUUID();
  const editsRoot = getEditsDir(opts.deviceId);
  const midMp4 = path.join(editsRoot, `${TMP_PREFIX}-${tmpId}.mid.tmp.mp4`);
  const wavAbs = path.join(editsRoot, `${TMP_PREFIX}-${tmpId}.asr.wav`);

  const unlinkTmp = async (): Promise<void> => {
    await fs.unlink(midMp4).catch(() => undefined);
    await fs.unlink(wavAbs).catch(() => undefined);
  };

  const built = buildEditFfmpegArgs({
    inputPath: absPath,
    outputPath: midMp4,
    probe: { durationSec: durationSecSrc, hasAudio: probe.audio != null },
    plan,
    keepAudioDespiteMute: probe.audio != null,
  });

  logger.info({ deviceId: opts.deviceId, segmentApproxSec: built.segmentDurationSec }, "captions draft: ffmpeg preprocess started");

  const exitPrep = await runFfmpeg(built.args, () => undefined);
  if (exitPrep !== 0) {
    await unlinkTmp();
    throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 503);
  }

  let muxHasTimelineAudio = probe.audio != null;
  let timelineGuess = built.segmentDurationSec > 0 ? built.segmentDurationSec : durationSecSrc;
  try {
    const midPb = await ffprobeMedia(midMp4);
    muxHasTimelineAudio = midPb.audio != null;
    if (midPb.durationMs > 0) timelineGuess = midPb.durationMs / 1000;
  } catch {
    await unlinkTmp();
    throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 503);
  }

  let segmentsRaw: TranscriptSegment[] = [];
  if (!muxHasTimelineAudio) {
    logger.info({ deviceId: opts.deviceId, segmentCount: 0 }, "captions draft: no audio track on trimmed timeline");
  } else {
    const wavOk = await ffmpegExtractMonoWav16k(midMp4, wavAbs);
    if (wavOk !== 0) {
      await unlinkTmp();
      throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 503);
    }
    try {
      const tx = await transcribeAudioFile({
        audioPath: wavAbs,
        apiKey: config.openaiApiKey,
        model: config.openaiTranscriptionModel,
      });
      segmentsRaw = tx.segments ?? [];
    } catch (err) {
      await unlinkTmp();
      logger.warn(
        { deviceId: opts.deviceId, errTag: err instanceof AppError ? err.code : typeof err },
        "captions draft: transcription failure"
      );
      throw new AppError(codes.CAPTIONS_DRAFT_UNAVAILABLE, DRAFT_UNAVAIL_MSG, 503);
    }
  }

  await unlinkTmp().catch(() => undefined);

  const maxT = timelineGuess > 0 ? timelineGuess : Number.POSITIVE_INFINITY;
  const clipped: TranscriptSegment[] = [];
  for (const s of segmentsRaw) {
    const st = Math.max(0, Math.min(maxT, s.startSec));
    const en = Math.max(st, Math.min(maxT, s.endSec));
    const t = typeof s.text === "string" ? s.text.trim() : "";
    if (t.length === 0) continue;
    if (en <= st + 1e-4) continue;
    clipped.push({ startSec: st, endSec: en, text: t });
  }

  const outSegments = clipped.map((s, i) => ({
    id: `seg_${i + 1}`,
    startSec: s.startSec,
    endSec: s.endSec,
    text: s.text,
  }));

  logger.info(
    {
      deviceId: opts.deviceId,
      segmentCount: outSegments.length,
      durationSec: timelineGuess > 0 ? timelineGuess : undefined,
      model: config.openaiTranscriptionModel,
    },
    "captions draft completed"
  );

  return {
    segments: outSegments,
    durationSec: timelineGuess > 0 ? timelineGuess : durationSecSrc,
    language: "auto",
  };
}
