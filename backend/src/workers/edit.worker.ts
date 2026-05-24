import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { Worker } from "bullmq";
import Redis from "ioredis";
import type { PrismaClient } from "@prisma/client";
import { config } from "../config";
import { EDIT_QUEUE_NAME } from "../plugins/queues";
import { buildEditFfmpegArgs, ffmpegProgressRatio } from "../modules/edit/edit.ffmpeg";
import {
  expectedEditOutputStorageKey,
  parseStoredOperations,
  resolveEditSource,
} from "../modules/edit/edit.service";
import { resolveEditOperations } from "../modules/edit/edit.schemas";
import type { EditQueuePayload } from "../modules/edit/edit.types";
import { ffprobeMedia } from "../services/ffmpegNormalize";
import { logger } from "../services/logger";
import { ensureDeviceDirs, getEditsDir } from "../services/storage";
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

        await prisma.editJob.update({
          where: { id: editJobId },
          data: { stage: "processing", progressPercent: 10 },
        });

        const built = buildEditFfmpegArgs({
          inputPath: source.absPath,
          outputPath: tmpOut,
          probe: { durationSec, hasAudio: probe.audio != null },
          plan,
        });

        logger.info(
          {
            editJobId,
            deviceId,
            sourceKind: source.sourceKind,
            ...(row.sourceDownloadJobId ? { sourceDownloadJobId: row.sourceDownloadJobId } : {}),
            ...(row.sourceUploadId ? { sourceUploadId: row.sourceUploadId } : {}),
            segmentDurationSec: built.segmentDurationSec,
            ...(plan.speedFactor != null ? { speedFactor: plan.speedFactor } : {}),
            mute: plan.mute,
            aspectRatio: plan.aspectRatio,
            compressPreset: plan.compressPreset,
          },
          "ffmpeg edit started"
        );

        let stderrAcc = "";
        let lastDbProgressAt = 0;
        let lastPct = 10;

        const exitCode = await runFfmpeg(built.args, (full) => {
          stderrAcc = full;
          const t = ffmpegProgressRatio(full);
          if (t == null || built.segmentDurationSec <= 0) return;
          const ratio = Math.min(1, Math.max(0, t / built.segmentDurationSec));
          const pct = Math.min(99, Math.round(10 + ratio * 89));
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

        if (exitCode !== 0) {
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, `ffmpeg exited with code ${exitCode}`, {
            stderrTail: stderrAcc,
          });
          return;
        }

        let st;
        try {
          st = await fs.stat(tmpOut);
        } catch {
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "Output missing after ffmpeg");
          return;
        }

        if (!st.isFile() || st.size <= 0) {
          await cleanupTmp();
          await markEditFailed(prisma, editJobId, codes.EDIT_FAILED, "Empty output after ffmpeg");
          return;
        }

        logger.info(
          { editJobId, deviceId, outputBytes: st.size },
          "ffmpeg edit completed"
        );

        await prisma.editJob.update({
          where: { id: editJobId },
          data: { stage: "finalizing", progressPercent: 99 },
        });

        await fs.unlink(finalOut).catch(() => undefined);
        await fs.rename(tmpOut, finalOut);

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
