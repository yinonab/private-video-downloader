import fs from "node:fs/promises";
import path from "node:path";
import { Worker } from "bullmq";
import Redis from "ioredis";
import type { PrismaClient } from "@prisma/client";
import { config } from "../config";
import { DOWNLOAD_QUEUE_NAME } from "../plugins/queues";
import type { QueuePayload } from "../modules/downloads/download.service";
import { ensureDeviceDirs, getAudioDir, getVideoDir } from "../services/storage";
import { buildDownloadArgs, parseYtDlpProgress, runYtDlpStreaming } from "../services/ytdlp";
import { logger } from "../services/logger";

function mimeForExt(ext: string): string {
  const e = ext.toLowerCase();
  if (e === ".mp4") return "video/mp4";
  if (e === ".webm") return "video/webm";
  if (e === ".mkv") return "video/x-matroska";
  if (e === ".mp3") return "audio/mpeg";
  if (e === ".m4a") return "audio/mp4";
  return "application/octet-stream";
}

export function createDownloadWorker(prisma: PrismaClient): Worker {
  const connection = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });

  const worker = new Worker(
    DOWNLOAD_QUEUE_NAME,
    async (bullJob) => {
      const data = bullJob.data as QueuePayload;
      const { jobId, deviceId, url, format } = data;

      await prisma.downloadJob.update({
        where: { id: jobId },
        data: { status: "running", progress: 0, error: null },
      });

      await ensureDeviceDirs(deviceId);

      const built = buildDownloadArgs({ url, deviceId, jobId, format });

      let lastDbWrite = 0;
      let stderrTail = "";

      const maybeReportProgress = (line: string): void => {
        const parsed = parseYtDlpProgress(line);
        if (!parsed) return;
        const now = Date.now();
        if (now - lastDbWrite < 1500) return;
        lastDbWrite = now;
        void prisma.downloadJob.update({
          where: { id: jobId },
          data: {
            progress: parsed.progress,
            speedText: parsed.speedText,
            etaText: parsed.etaText,
          },
        });
      };

      const streaming = runYtDlpStreaming(built.args, {
        onStdoutLine: (line) => {
          maybeReportProgress(line);
        },
        onStderrLine: (line) => {
          stderrTail = (stderrTail + "\n" + line).slice(-4000);
          maybeReportProgress(line);
        },
      });

      const { code } = await streaming.done;

      if (code !== 0) {
        const msg = stderrTail.trim() || `yt-dlp exited with ${code}`;
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: {
            status: "failed",
            progress: 0,
            error: msg.slice(0, 4000),
          },
        });
        await prisma.eventLog.create({
          data: {
            jobId,
            deviceId,
            level: "error",
            message: "download failed",
            meta: { code },
          },
        });
        logger.warn({ jobId, code }, "download failed");
        return;
      }

      const dir = built.subdir === "videos" ? getVideoDir(deviceId) : getAudioDir(deviceId);
      let entries: string[];
      try {
        entries = await fs.readdir(dir);
      } catch {
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: { status: "failed", error: "Output directory missing" },
        });
        return;
      }

      const candidates = entries.filter((f) => f.startsWith(`${jobId}.`));
      if (!candidates.length) {
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: { status: "failed", error: "Output file not found" },
        });
        return;
      }

      let best = candidates[0]!;
      let bestSize = 0;
      for (const name of candidates) {
        const st = await fs.stat(path.join(dir, name)).catch(() => null);
        const sz = st?.size ?? 0;
        if (sz >= bestSize) {
          bestSize = sz;
          best = name;
        }
      }

      const bestPath = path.join(dir, best);
      const ext = path.extname(best);
      const mimeType = mimeForExt(ext);
      const storageKey = path.posix.join("devices", deviceId, built.subdir, best);

      await prisma.fileAsset.create({
        data: {
          deviceId,
          jobId,
          type: built.subdir === "videos" ? "video" : "audio",
          storageKey,
          filename: best,
          mimeType,
          sizeBytes: BigInt(bestSize),
        },
      });

      await prisma.downloadJob.update({
        where: { id: jobId },
        data: {
          status: "done",
          progress: 100,
          speedText: null,
          etaText: null,
          error: null,
        },
      });

      logger.info({ jobId, storageKey }, "download completed");
    },
    {
      connection,
      concurrency: config.DOWNLOAD_CONCURRENCY,
    }
  );

  worker.on("failed", (job, err) => {
    logger.error({ jobId: job?.id, err }, "bullmq job failed");
  });

  return worker;
}
