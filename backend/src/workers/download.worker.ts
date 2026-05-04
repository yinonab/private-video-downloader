import fs from "node:fs/promises";
import path from "node:path";
import { Worker } from "bullmq";
import Redis from "ioredis";
import type { PrismaClient } from "@prisma/client";
import { config } from "../config";
import { DOWNLOAD_QUEUE_NAME } from "../plugins/queues";
import type { QueuePayload } from "../modules/downloads/download.service";
import { ensureDeviceDirs, getAudioDir, getVideoDir } from "../services/storage";
import {
  buildDownloadArgs,
  extractFormatArg,
  formatDownloadFailureMessage,
  parseYtDlpProgress,
  runYtDlpStreaming,
  stderrMeansUnavailableFormat,
  type DownloadFormatKind,
} from "../services/ytdlp";
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

const VIDEO_QUALITY_FORMATS: DownloadFormatKind[] = ["1080p", "720p", "480p"];

export function createDownloadWorker(prisma: PrismaClient): Worker {
  const connection = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });

  const worker = new Worker(
    DOWNLOAD_QUEUE_NAME,
    async (bullJob) => {
      const data = bullJob.data as QueuePayload;
      const { jobId, deviceId, url, format } = data;

      const jobRow = await prisma.downloadJob.findUnique({
        where: { id: jobId },
        include: { link: true },
      });
      const platformLabel = jobRow?.link?.platform ?? jobRow?.link?.extractor ?? "unknown";

      await prisma.downloadJob.update({
        where: { id: jobId },
        data: { status: "running", progress: 0, error: null },
      });

      await ensureDeviceDirs(deviceId);

      let lastStderr = "";
      let lastArgs: string[] = [];
      let fallbackAttempted = false;
      let primaryFormatStr = "";

      const maybeReportProgress = (() => {
        let lastDbWrite = 0;
        return (line: string): void => {
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
      })();

      const runYtDlpOnce = async (args: string[]): Promise<number | null> => {
        lastStderr = "";
        const streaming = runYtDlpStreaming(args, {
          onStdoutLine: (line) => {
            maybeReportProgress(line);
          },
          onStderrLine: (line) => {
            lastStderr = (lastStderr + "\n" + line).slice(-8000);
            maybeReportProgress(line);
          },
        });
        const { code } = await streaming.done;
        return code;
      };

      const primaryBuilt = buildDownloadArgs({ url, deviceId, jobId, format });
      lastArgs = primaryBuilt.args;
      primaryFormatStr = extractFormatArg(primaryBuilt.args) ?? "(unknown)";

      let code = await runYtDlpOnce(primaryBuilt.args);

      if (
        code !== 0 &&
        stderrMeansUnavailableFormat(lastStderr) &&
        VIDEO_QUALITY_FORMATS.includes(format)
      ) {
        fallbackAttempted = true;
        const fbBuilt = buildDownloadArgs({ url, deviceId, jobId, format: "best" });
        lastArgs = fbBuilt.args;
        logger.warn(
          {
            jobId,
            platform: platformLabel,
            requestedQuality: format,
            primaryYtDlpFormat: primaryFormatStr,
            fallbackAttempted: true,
            fallbackFormatString: extractFormatArg(fbBuilt.args),
          },
          "yt-dlp retrying with best fallback after unavailable format"
        );
        code = await runYtDlpOnce(fbBuilt.args);
      }

      if (
        code !== 0 &&
        stderrMeansUnavailableFormat(lastStderr) &&
        format === "audio_mp3"
      ) {
        fallbackAttempted = true;
        const again = buildDownloadArgs({ url, deviceId, jobId, format: "audio_mp3" });
        lastArgs = again.args;
        logger.warn(
          {
            jobId,
            platform: platformLabel,
            requestedQuality: format,
            primaryYtDlpFormat: primaryFormatStr,
            fallbackAttempted: true,
            fallbackFormatString: extractFormatArg(again.args),
          },
          "yt-dlp retrying audio pipeline once after unavailable format"
        );
        code = await runYtDlpOnce(again.args);
      }

      const finalFormatStr = extractFormatArg(lastArgs) ?? primaryFormatStr;

      if (code !== 0) {
        const userMsg = formatDownloadFailureMessage(lastStderr, fallbackAttempted);
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: {
            status: "failed",
            progress: 0,
            error: userMsg.slice(0, 4000),
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
        logger.warn(
          {
            jobId,
            platform: platformLabel,
            requestedQuality: format,
            primaryYtDlpFormat: primaryFormatStr,
            fallbackAttempted,
            finalFormatString: finalFormatStr,
            stderrTail: lastStderr.trim().slice(-2000),
          },
          "download failed"
        );
        return;
      }

      const dir = primaryBuilt.subdir === "videos" ? getVideoDir(deviceId) : getAudioDir(deviceId);
      let entries: string[];
      try {
        entries = await fs.readdir(dir);
      } catch {
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: { status: "failed", error: OUTPUT_INVALID_MSG },
        });
        return;
      }

      const candidates = entries.filter((f) => f.startsWith(`${jobId}.`));
      if (!candidates.length) {
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: { status: "failed", error: OUTPUT_INVALID_MSG },
        });
        logger.warn({ jobId, dir }, "download output file missing");
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
      if (bestSize <= 0) {
        await prisma.downloadJob.update({
          where: { id: jobId },
          data: { status: "failed", error: OUTPUT_INVALID_MSG },
        });
        logger.warn(
          {
            jobId,
            platform: platformLabel,
            requestedQuality: format,
            outputPath: bestPath,
            outputBytes: bestSize,
          },
          "download output empty"
        );
        return;
      }

      const ext = path.extname(best);
      const mimeType = mimeForExt(ext);
      const storageKey = path.posix.join("devices", deviceId, primaryBuilt.subdir, best);

      await prisma.fileAsset.create({
        data: {
          deviceId,
          jobId,
          type: primaryBuilt.subdir === "videos" ? "video" : "audio",
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

      logger.info(
        {
          jobId,
          platform: platformLabel,
          requestedQuality: format,
          primaryYtDlpFormat: primaryFormatStr,
          fallbackAttempted,
          finalFormatString: finalFormatStr,
          outputPath: bestPath,
          outputBytes: bestSize,
        },
        "download completed"
      );
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

const OUTPUT_INVALID_MSG = "לא ניתן להוריד את הסרטון הזה בפורמט זמין.";
