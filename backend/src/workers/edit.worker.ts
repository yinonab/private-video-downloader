import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { Worker } from "bullmq";
import Redis from "ioredis";
import type { PrismaClient } from "@prisma/client";
import { config } from "../config";
import { EDIT_QUEUE_NAME } from "../plugins/queues";
import { buildEditFinalEncodeAfterCaptionsArgs, buildEditFfmpegArgs, ffmpegProgressRatio } from "../modules/edit/edit.ffmpeg";
import {
  expectedEditOutputStorageKey,
  parseStoredOperations,
  resolveEditSource,
} from "../modules/edit/edit.service";
import { resolveEditOperations } from "../modules/edit/edit.schemas";
import type { EditQueuePayload } from "../modules/edit/edit.types";
import type { TranscriptSegment } from "../services/transcription.service";
import { segmentsToAssContentWithMeta } from "../services/assSubtitles.service";
import { ffprobeMedia } from "../services/ffmpegNormalize";
import { ffmpegSubtitlesVFArgument } from "../services/ffmpegSubtitlePath";
import { logger } from "../services/logger";
import { ensureDeviceDirs, getEditsDir } from "../services/storage";
import { transcribeAudioFile } from "../services/transcription.service";
import { AppError, codes } from "../types/errors";

const STDERR_CAP = 512_000;
const EDIT_WORKER_CONCURRENCY = 1;

async function runFfmpeg(args: string[], onStderr: (fullStderr: string) => void): Promise<number | null> {
  return new Promise((resolve) => {
    const child = spawn("ffmpeg", args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      if (stderr.length > STDERR_CAP) stderr = stderr.slice(-Math.floor(STDERR_CAP / 2));
      onStderr(stderr);
    });
    child.on("error", (err) => {
      logger.error({ err }, "ffmpeg spawn error (edit)");
      resolve(null);
    });
    child.on("close", (code) => resolve(code));
  });
}

async function markEditFailed(
  prisma: PrismaClient,
  editJobId: string,
  errorCode: string,
  errorMessage: string,
  logMeta?: { stderrTail?: string }
): Promise<void> {
  await prisma.editJob.update({
    where: { id: editJobId },
    data: {
      status: "failed",
      stage: "failed",
      progressPercent: null,
      errorCode,
      errorMessage: errorMessage.slice(0, 2000),
      completedAt: new Date(),
    },
  });
  logger.warn(
    { editJobId, errorCode, stderrTail: logMeta?.stderrTail?.slice(-4000) },
    "edit job failed"
  );
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

export function createEditWorker(prisma: PrismaClient): Worker {
  const connection = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });

  const worker = new Worker(
    EDIT_QUEUE_NAME,
    async (bullJob) => {
      const { editJobId, deviceId } = bullJob.data as EditQueuePayload;
      const tmpOut = path.join(getEditsDir(deviceId), `${editJobId}.part.mp4`);
      const finalOut = path.join(getEditsDir(deviceId), `${editJobId}.mp4`);

      const cleanupTmp = async (): Promise<void> => {
        await fs.unlink(tmpOut).catch(() => undefined);
      };

      const editsRoot = getEditsDir(deviceId);
      const captionMidAbs = path.join(editsRoot, `${editJobId}.mid.tmp.mp4`);
      const wavAbs = path.join(editsRoot, `${editJobId}.asr.wav`);
      const assAbs = path.join(editsRoot, `${editJobId}.cap.tmp.ass`);

      const unlinkCaptionArtifacts = async (): Promise<void> => {
        await fs.unlink(captionMidAbs).catch(() => undefined);
        await fs.unlink(wavAbs).catch(() => undefined);
        await fs.unlink(assAbs).catch(() => undefined);
      };

      try {
        const row = await prisma.editJob.findUnique({ where: { id: editJobId } });
        if (!row || row.deviceId !== deviceId) {
          logger.error({ editJobId, deviceId }, "edit worker: job row missing or device mismatch");
          return;
        }

        await prisma.editJob.update({
          where: { id: editJobId },
          data: { status: "running", stage: "validating_source", progressPercent: 0 },
        });

        const source = await resolveEditSource({
          prisma,
          row,
          deviceId,
          log: { editJobId },
        });

        await prisma.editJob.update({
          where: { id: editJobId },
          data: { stage: "probing", progressPercent: 5 },
        });

        let probe;
        try {
          probe = await ffprobeMedia(source.absPath);
        } catch {
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "ffprobe failed on source");
          return;
        }

        const durationSec = probe.durationMs > 0 ? probe.durationMs / 1000 : 0;
        if (!probe.video || durationSec <= 0) {
          await cleanupTmp();
          await markEditFailed(
            prisma,
            editJobId,
            codes.EDIT_INVALID_SOURCE,
            "Source has no usable video stream or duration"
          );
          return;
        }

        let ops;
        try {
          ops = parseStoredOperations(row.operationsJson);
        } catch {
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "Invalid stored operations");
          return;
        }

        const plan = resolveEditOperations(ops);
        if (plan.trim != null && plan.trim.startSec >= durationSec) {
          await cleanupTmp();
          await markEditFailed(
            prisma,
            editJobId,
            codes.EDIT_INVALID_SOURCE,
            "Trim start is beyond video duration"
          );
          return;
        }

        await ensureDeviceDirs(deviceId);
        await fs.unlink(tmpOut).catch(() => undefined);

        const captionsV1 = plan.captionsBurnInV1 != null;

        await prisma.editJob.update({
          where: { id: editJobId },
          data: { stage: "processing", progressPercent: 10 },
        });

        /** Single-pass timeline OR intermediate MP4 aligned to Whisper timeline (trim→rotate→format→speed→AAC). */
        let builtIntermediate = buildEditFfmpegArgs({
          inputPath: source.absPath,
          outputPath: captionsV1 ? captionMidAbs : tmpOut,
          probe: { durationSec, hasAudio: probe.audio != null },
          plan,
          keepAudioDespiteMute: captionsV1 && probe.audio != null,
        });

        logger.info(
          {
            editJobId,
            deviceId,
            sourceKind: source.sourceKind,
            ...(row.sourceDownloadJobId ? { sourceDownloadJobId: row.sourceDownloadJobId } : {}),
            ...(row.sourceUploadId ? { sourceUploadId: row.sourceUploadId } : {}),
            segmentDurationSec: builtIntermediate.segmentDurationSec,
            captionsBurnInPipeline: captionsV1,
          ...(plan.speedFactor != null ? { speedFactor: plan.speedFactor } : {}),
          ...(plan.rotationDegrees != null ? { rotationDegrees: plan.rotationDegrees } : {}),
          ...(plan.formatMode != null ? { formatMode: plan.formatMode } : {}),
            mute: plan.mute,
            aspectRatio: plan.aspectRatio,
            compressPreset: plan.compressPreset,
          },
          "ffmpeg edit started"
        );

        let stderrAcc = "";
        let lastDbProgressAt = 0;
        let lastPct = 10;

        const exitIntermediate = await runFfmpeg(builtIntermediate.args, (full) => {
          stderrAcc = full;
          const t = ffmpegProgressRatio(full);
          if (t == null || builtIntermediate.segmentDurationSec <= 0) return;
          const ratio = Math.min(1, Math.max(0, t / builtIntermediate.segmentDurationSec));
          const pct = captionsV1
            ? Math.min(48, Math.round(11 + ratio * 36))
            : Math.min(99, Math.round(10 + ratio * 89));
          const now = Date.now();
          if (now - lastDbProgressAt < 2000 && pct <= lastPct) return;
          lastDbProgressAt = now;
          lastPct = pct;
          void prisma.editJob
            .update({
              where: { id: editJobId },
              data: { progressPercent: pct },
            })
            .catch(() => undefined);
        });

        if (exitIntermediate !== 0) {
          await unlinkCaptionArtifacts();
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, `ffmpeg exited with code ${exitIntermediate}`, {
            stderrTail: stderrAcc,
          });
          return;
        }

        if (captionsV1) {
          let muxHasTimelineAudio = probe.audio != null;
          let timelineDurationSecGuess = builtIntermediate.segmentDurationSec;

          const captionCfg = plan.captionsBurnInV1!;
          const segmentsFromClient = captionCfg.mode === "segments";

          if (!segmentsFromClient && !config.openaiApiKey) {
            await unlinkCaptionArtifacts();
            await cleanupTmp();
            await markEditFailed(
              prisma,
              editJobId,
              codes.CAPTIONS_TRANSCRIPTION_UNAVAILABLE,
              "Automatic captions are not configured on this server."
            );
            return;
          }

          let midDurSec = timelineDurationSecGuess;
          try {
            const midPb = await ffprobeMedia(captionMidAbs);
            midDurSec = midPb.durationMs > 0 ? midPb.durationMs / 1000 : midDurSec;
            muxHasTimelineAudio = midPb.audio != null;
          } catch {
            await unlinkCaptionArtifacts();
            await cleanupTmp();
            await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "ffprobe failed on intermediate timeline");
            return;
          }
          timelineDurationSecGuess = midDurSec > 0 ? midDurSec : timelineDurationSecGuess;

          await prisma.editJob.update({
            where: { id: editJobId },
            data: {
              stage: segmentsFromClient ? "captions_prep" : "captions_transcription",
              progressPercent: Math.max(lastPct, 49),
            },
          });

          let segments: TranscriptSegment[] = [];

          function clampCueTimesToTimeline(
            segs: readonly {
              readonly startSec: number;
              readonly endSec: number;
              readonly text: string;
              readonly words?: readonly { readonly startSec: number; readonly endSec: number; readonly text: string }[];
            }[],
            timelineSec: number
          ): TranscriptSegment[] {
            const upper = timelineSec > 0 && Number.isFinite(timelineSec) ? timelineSec : Number.POSITIVE_INFINITY;
            const outCue: TranscriptSegment[] = [];
            for (const s of segs) {
              const st = Math.max(0, Math.min(upper, s.startSec));
              const en = Math.max(st, Math.min(upper, s.endSec));
              const t = typeof s.text === "string" ? s.text.trim() : "";
              if (t.length === 0) continue;
              if (en <= st + 1e-4) continue;
              const words = Array.isArray(s.words)
                ? s.words
                    .map((w) => {
                      const wst = Math.max(st, Math.min(en, w.startSec));
                      const wen = Math.max(wst, Math.min(en, w.endSec));
                      const wt = typeof w.text === "string" ? w.text.trim() : "";
                      if (!wt || wen <= wst + 1e-4) return null;
                      return { startSec: wst, endSec: wen, text: wt };
                    })
                    .filter((w): w is { startSec: number; endSec: number; text: string } => w != null)
                : undefined;
              outCue.push({ startSec: st, endSec: en, text: t, words: words?.length ? words : undefined });
            }
            return outCue;
          }

          if (segmentsFromClient) {
            segments = clampCueTimesToTimeline(captionCfg.segments ?? [], timelineDurationSecGuess);
            logger.info({ editJobId, segmentCount: segments.length }, "captions: client segment mode — skipping transcription");
          } else if (!muxHasTimelineAudio) {
            logger.warn({ editJobId }, "captions burn-in skipped: timeline has no audio track");
          } else {
            const wx = await ffmpegExtractMonoWav16k(captionMidAbs, wavAbs);
            if (wx !== 0) {
              await unlinkCaptionArtifacts();
              await cleanupTmp();
              await markEditFailed(
                prisma,
                editJobId,
                codes.CAPTIONS_GENERATION_FAILED,
                "Could not extract audio for transcription"
              );
              return;
            }
            try {
              segments = (
                await transcribeAudioFile({
                  audioPath: wavAbs,
                  apiKey: config.openaiApiKey,
                  model: config.openaiTranscriptionModel,
                  editJobId,
                })
              ).segments;
            } catch (txErr) {
              await unlinkCaptionArtifacts();
              await cleanupTmp();
              if (txErr instanceof AppError) {
                await markEditFailed(prisma, editJobId, txErr.code, txErr.message);
              } else {
                await markEditFailed(
                  prisma,
                  editJobId,
                  codes.CAPTIONS_GENERATION_FAILED,
                  "Transcription failed"
                );
              }
              return;
            }
          }

          let subtitlesVfClause: string | null = null;
          if (segments.length > 0) {
            const cfg = captionCfg;
            const assOut = segmentsToAssContentWithMeta(segments, {
              title: `edit-${editJobId}-cap`,
              ...cfg,
            });
            await fs.writeFile(assAbs, assOut.ass, "utf8");
            subtitlesVfClause = ffmpegSubtitlesVFArgument(assAbs);
            logger.info(
              {
                editJobId,
                segmentCount: segments.length,
                wordCount: assOut.wordCount,
                highlightMode: cfg.wordHighlight,
                usedFallbackTiming: assOut.usedFallbackTiming,
              },
              "captions burn-in ASS prepared"
            );
          } else {
            logger.warn({ editJobId }, "captions: no subtitle segments — exporting without burn-in overlays");
          }

          await prisma.editJob.update({
            where: { id: editJobId },
            data: { stage: "captions_encode", progressPercent: Math.max(lastPct + 2, 55) },
          });

          /** Final compress + mute on mux + optional subtitles burn (`subtitles`/libass filter). */
          const builtFinal = buildEditFinalEncodeAfterCaptionsArgs({
            intermediatePath: captionMidAbs,
            outputPath: tmpOut,
            plan,
            videoFilter: subtitlesVfClause,
            intermediateHasAudio: muxHasTimelineAudio,
            timelineDurationSec: timelineDurationSecGuess > 0 ? timelineDurationSecGuess : 1,
          });

          lastDbProgressAt = Date.now();
          lastPct = 55;
          const exitFinal = await runFfmpeg(builtFinal.args, (full) => {
            stderrAcc = full;
            const t = ffmpegProgressRatio(full);
            if (t == null || builtFinal.segmentDurationSec <= 0) return;
            const ratio = Math.min(1, Math.max(0, t / builtFinal.segmentDurationSec));
            const pct = Math.min(98, Math.round(55 + ratio * 43));
            const now = Date.now();
            if (now - lastDbProgressAt < 2000 && pct <= lastPct) return;
            lastDbProgressAt = now;
            lastPct = pct;
            void prisma.editJob
              .update({
                where: { id: editJobId },
                data: { progressPercent: pct },
              })
              .catch(() => undefined);
          });

          if (exitFinal !== 0) {
            await unlinkCaptionArtifacts();
            await cleanupTmp();
            await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, `ffmpeg final encode exited with code ${exitFinal}`, {
              stderrTail: stderrAcc,
            });
            return;
          }

          await unlinkCaptionArtifacts().catch(() => undefined);
        }

        let st;
        try {
          st = await fs.stat(tmpOut);
        } catch {
          await unlinkCaptionArtifacts();
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "Output missing after ffmpeg");
          return;
        }

        if (!st.isFile() || st.size <= 0) {
          await unlinkCaptionArtifacts();
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "Empty output after ffmpeg");
          return;
        }

        logger.info(
          { editJobId, deviceId, outputBytes: st.size },
          captionsV1 ? "ffmpeg captions pipeline completed" : "ffmpeg edit completed"
        );

        await prisma.editJob.update({
          where: { id: editJobId },
          data: { stage: "finalizing", progressPercent: 99 },
        });

        await fs.unlink(finalOut).catch(() => undefined);
        await fs.rename(tmpOut, finalOut);

        await unlinkCaptionArtifacts().catch(() => undefined);

        const storageKey = expectedEditOutputStorageKey(deviceId, editJobId);
        const completedAt = new Date();

        await prisma.editJob.update({
          where: { id: editJobId },
          data: {
            status: "done",
            stage: "done",
            progressPercent: 100,
            outputStorageKey: storageKey,
            outputFilename: `${editJobId}.mp4`,
            outputMimeType: "video/mp4",
            outputSizeBytes: BigInt(st.size),
            errorCode: null,
            errorMessage: null,
            completedAt,
          },
        });
      } catch (err) {
        await unlinkCaptionArtifacts();
        await cleanupTmp();
        const msg = err instanceof AppError ? err.message : err instanceof Error ? err.message : String(err);
        const code = err instanceof AppError ? err.code : codes.EDIT_FAILED;
        logger.error({ editJobId, deviceId, err }, "edit worker unexpected error");
        await markEditFailed(prisma, editJobId, code, msg);
      }
    },
    {
      connection,
      concurrency: EDIT_WORKER_CONCURRENCY,
    }
  );

  worker.on("failed", (job, err) => {
    logger.error({ editJobId: job?.id, err }, "bullmq edit job failed");
  });

  return worker;
}
