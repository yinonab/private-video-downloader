import { randomBytes } from "node:crypto";
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
  DOWNLOAD_JOB_ERROR_NORMALIZE_FAILED,
  ffmpegNormalizeCommandShape,
  ffprobeMedia,
  runFfmpegAudioNormalize,
  runFfmpegFullTranscode,
  runFfmpegRemux,
  selectNormalizeStrategy,
  type NormalizeStrategy,
  type ProbeResult,
} from "../services/ffmpegNormalize";
import {
  createProgressThrottler,
  updateDownloadJobProgress,
} from "../services/jobProgress";
import {
  downloadFacebookMp4ToFile,
  extractFacebookDirectMedia,
  pickFacebookMp4UrlForFormat,
} from "../services/facebookFallbackExtractor";
import {
  buildDownloadArgs,
  classifyYtDlpStderr,
  extractFormatArg,
  formatDownloadFailureMessage,
  LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE,
  parseYtDlpProgress,
  runYtDlpStreaming,
  stderrMeansUnavailableFormat,
  withYtDlpCookiesArgs,
  type DownloadFormatKind,
} from "../services/ytdlp";
import { withYtDlpPoTokenArgs } from "../services/ytdlpPoToken";
import {
  applyYtDlpYouTubeTransportArgs,
  ytdlpProxyContextFromUrl,
} from "../services/ytdlpProxy";
import { logger } from "../services/logger";
import {
  notifyDownloadWorkerBullUncaught,
  notifyDownloadWorkerFailed,
  safeHostFromUrlString,
} from "../services/operationalAlerts";
import { runPrimaryYtDlpWithTikTokRehydrationRetry } from "../services/downloadTikTokRehydrationRetry";
import {
  formatSelectorSuggestsMerge,
  logDownloadPerf,
  startPerfTimer,
} from "../services/downloadPerf";

function mimeForExt(ext: string): string {
  const e = ext.toLowerCase();
  if (e === ".mp4") return "video/mp4";
  if (e === ".webm") return "video/webm";
  if (e === ".mkv") return "video/x-matroska";
  if (e === ".mp3") return "audio/mpeg";
  if (e === ".m4a") return "audio/mp4";
  return "application/octet-stream";
}

const VIDEO_QUALITY_FORMATS: DownloadFormatKind[] = ["1080p", "720p", "480p", "tiktok_ready"];

async function downloadFacebookFallbackMp4(
  sourceUrl: string,
  format: DownloadFormatKind,
  destFsPath: string
): Promise<number> {
  const maxAttempts = 2;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const ex = await extractFacebookDirectMedia(sourceUrl);
    if (!ex.ok) {
      logger.warn({ facebook_direct_dl_attempt: attempt + 1, reason: ex.reason }, "facebook direct — re-extract failed");
      continue;
    }
    const mp4 = pickFacebookMp4UrlForFormat(format, ex.candidates);
    if (!mp4) {
      logger.warn({ facebook_direct_dl_attempt: attempt + 1 }, "facebook direct — no mp4 for format");
      continue;
    }
    try {
      await downloadFacebookMp4ToFile(mp4, destFsPath);
      return 0;
    } catch (err) {
      logger.warn(
        {
          facebook_direct_dl_attempt: attempt + 1,
          err: err instanceof Error ? err.message : String(err),
        },
        "facebook direct mp4 download attempt failed"
      );
    }
  }
  return 1;
}

function stageForStrategy(s: NormalizeStrategy): string {
  switch (s) {
    case "remux":
      return "remuxing";
    case "audio_only":
      return "normalizing_audio";
    default:
      return "full_transcoding";
  }
}

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
      const facebookDirectFallback = Boolean(jobRow?.link?.facebookDirectFallback);
      const isTikTokReady = format === "tiktok_ready";

      logger.info(
        {
          jobId,
          platform: platformLabel,
          requestedFormat: format,
          normalizedFormat: format,
          isTikTokReady,
          normalizationEnabled: isTikTokReady,
        },
        "download worker job picked"
      );

      const jobCreatedAtMs = jobRow?.createdAt ? jobRow.createdAt.getTime() : Date.now();
      const workerPickedAtMs = Date.now();
      const runningTimer = startPerfTimer();

      await updateDownloadJobProgress(
        prisma,
        jobId,
        {
          status: "running",
          processingStage: "preparing",
          progress: null,
          error: null,
          speedText: null,
          etaText: null,
        },
        { platform: platformLabel, requestedQuality: format, logMessage: "download picked — preparing" }
      );

      logDownloadPerf({
        stage: "queue_wait",
        durationMs: Math.max(0, workerPickedAtMs - jobCreatedAtMs),
        jobId,
        platform: platformLabel,
        quality: format,
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
          const pct = parsed.progress > 0 ? parsed.progress : null;
          void updateDownloadJobProgress(
            prisma,
            jobId,
            {
              processingStage: "downloading",
              progress: pct,
              speedText: parsed.speedText,
              etaText: parsed.etaText,
            },
            { platform: platformLabel, requestedQuality: format, logMessage: "yt-dlp progress updated" }
          );
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
      primaryFormatStr = extractFormatArg(primaryBuilt.args) ?? "(unknown)";

      if (isTikTokReady) {
        logger.info(
          {
            jobId,
            platform: platformLabel,
            quality: format,
            formatSelector: primaryFormatStr,
            tiktokReadyCompatiblePreferred: true,
            normalizationEnabled: true,
          },
          "tiktok_ready using AVC/H.264-preferring format selector"
        );
      }

      if (facebookDirectFallback && format === "audio_mp3") {
        const msg =
          "Audio MP3 is not available for this Facebook video. Choose a video quality instead.";
        await updateDownloadJobProgress(
          prisma,
          jobId,
          {
            status: "failed",
            processingStage: "failed",
            progress: null,
            error: msg,
            speedText: null,
            etaText: null,
          },
          {
            platform: platformLabel,
            requestedQuality: format,
            logMessage: "facebook fallback — audio_mp3 not supported",
          }
        );
        logger.warn({ jobId, platform: platformLabel }, "facebook fallback — audio_mp3 not supported");
        notifyDownloadWorkerFailed({
          jobId,
          deviceId,
          url,
          platformLabel,
          classification: "facebook_audio_mp3_unsupported",
          facebookDirectFallback: true,
          actionHint: "User chose audio on Facebook fallback video — product limitation.",
        });
        return;
      }

      let code: number;
      const sourceDownloadTimer = startPerfTimer();

      if (facebookDirectFallback) {
        await updateDownloadJobProgress(
          prisma,
          jobId,
          { processingStage: "downloading", progress: null },
          { platform: platformLabel, requestedQuality: format, logMessage: "facebook direct — downloading" }
        );

        const videoDir = getVideoDir(deviceId);
        try {
          const names = await fs.readdir(videoDir);
          for (const n of names) {
            if (n.startsWith(`${jobId}.`)) await fs.unlink(path.join(videoDir, n)).catch(() => {});
          }
        } catch {
          /* ignore */
        }

        const destPath = path.join(videoDir, `${jobId}.mp4`);
        code = await downloadFacebookFallbackMp4(url, format, destPath);
        lastStderr = code !== 0 ? "facebook_direct_download_failed" : "";
        lastArgs = ["facebook_direct_fallback"];
      } else {
        code = await withYtDlpCookiesArgs(async (cookiesArgs) => {
          const transportContext = ytdlpProxyContextFromUrl(url, "download", {
            platform: platformLabel,
            requestedFormat: format,
            requestedQuality: format,
          });
          const prefixArgs = (base: string[]) =>
            applyYtDlpYouTubeTransportArgs([...cookiesArgs, ...base], transportContext, withYtDlpPoTokenArgs);

          lastArgs = prefixArgs(primaryBuilt.args);

          await updateDownloadJobProgress(
            prisma,
            jobId,
            { processingStage: "downloading", progress: null },
            { platform: platformLabel, requestedQuality: format }
          );

          const urlHost = safeHostFromUrlString(url);
          const primaryRetry = await runPrimaryYtDlpWithTikTokRehydrationRetry({
            jobId,
            urlHost,
            platformLabel: String(platformLabel),
            runAttempt: async () => (await runYtDlpOnce(prefixArgs(primaryBuilt.args))) ?? 1,
            classifyAfterAttempt: () => classifyYtDlpStderr(lastStderr, { urlHost }),
            clearPartials: async () => {
              const outDir =
                primaryBuilt.subdir === "videos" ? getVideoDir(deviceId) : getAudioDir(deviceId);
              try {
                const names = await fs.readdir(outDir);
                for (const n of names) {
                  if (n.startsWith(`${jobId}.`)) {
                    await fs.unlink(path.join(outDir, n)).catch(() => {});
                  }
                }
              } catch {
                /* ignore */
              }
            },
          });

          let innerCode = primaryRetry.code;

          if (
            innerCode !== 0 &&
            stderrMeansUnavailableFormat(lastStderr) &&
            VIDEO_QUALITY_FORMATS.includes(format)
          ) {
            fallbackAttempted = true;
            const fbBuilt = buildDownloadArgs({ url, deviceId, jobId, format: "best" });
            lastArgs = prefixArgs(fbBuilt.args);
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
            innerCode = (await runYtDlpOnce(prefixArgs(fbBuilt.args))) ?? 1;
          }

          if (
            innerCode !== 0 &&
            stderrMeansUnavailableFormat(lastStderr) &&
            format === "audio_mp3"
          ) {
            fallbackAttempted = true;
            const again = buildDownloadArgs({ url, deviceId, jobId, format: "audio_mp3" });
            lastArgs = prefixArgs(again.args);
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
            innerCode = (await runYtDlpOnce(prefixArgs(again.args))) ?? 1;
          }

          return innerCode;
        });
      }

      const finalFormatStr = extractFormatArg(lastArgs) ?? primaryFormatStr;

      if (code !== 0) {
        const userMsg = facebookDirectFallback
          ? "We couldn't download this Facebook video right now. Try again later or choose another quality."
          : formatDownloadFailureMessage(lastStderr, fallbackAttempted, platformLabel);
        await updateDownloadJobProgress(
          prisma,
          jobId,
          {
            status: "failed",
            processingStage: "failed",
            progress: null,
            error: userMsg.slice(0, 4000),
            speedText: null,
            etaText: null,
          },
          { platform: platformLabel, requestedQuality: format, logMessage: "download final status updated — failed" }
        );
        await prisma.eventLog.create({
          data: {
            jobId,
            deviceId,
            level: "error",
            message: "download failed",
            meta: {
              code,
              stderrClassification: facebookDirectFallback
                ? "facebook_direct"
                : classifyYtDlpStderr(lastStderr, { urlHost: safeHostFromUrlString(url) }),
            },
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
            stderrClassification: facebookDirectFallback
              ? "facebook_direct"
              : classifyYtDlpStderr(lastStderr, { urlHost: safeHostFromUrlString(url) }),
            ...(facebookDirectFallback ? {} : { stderrTail: lastStderr.trim().slice(-2000) }),
          },
          "download failed"
        );
        const stderrClassification = facebookDirectFallback
          ? undefined
          : classifyYtDlpStderr(lastStderr, { urlHost: safeHostFromUrlString(url) });
        const drmFailure = stderrClassification === "drm_protected";
        notifyDownloadWorkerFailed({
          jobId,
          deviceId,
          url,
          platformLabel,
          classification: facebookDirectFallback ? "facebook_direct" : stderrClassification ?? "unknown",
          facebookDirectFallback,
          stderrTail: facebookDirectFallback || drmFailure ? undefined : lastStderr,
          stderrClassification,
        });
        return;
      }

      const dir = primaryBuilt.subdir === "videos" ? getVideoDir(deviceId) : getAudioDir(deviceId);
      let entries: string[];
      try {
        entries = await fs.readdir(dir);
      } catch {
        await updateDownloadJobProgress(prisma, jobId, {
          status: "failed",
          processingStage: "failed",
          progress: null,
          error: LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE,
        });
        notifyDownloadWorkerFailed({
          jobId,
          deviceId,
          url,
          platformLabel,
          classification: "output_directory_unreadable",
          facebookDirectFallback: false,
          actionHint: "Cannot read device output directory — check storage volume permissions.",
        });
        return;
      }

      const candidates = entries.filter((f) => f.startsWith(`${jobId}.`));
      if (!candidates.length) {
        await updateDownloadJobProgress(prisma, jobId, {
          status: "failed",
          processingStage: "failed",
          progress: null,
          error: LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE,
        });
        logger.warn({ jobId, dir }, "download output file missing");
        notifyDownloadWorkerFailed({
          jobId,
          deviceId,
          url,
          platformLabel,
          classification: "output_file_missing",
          facebookDirectFallback: false,
          actionHint: "yt-dlp reported success but expected output file prefix is missing.",
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
      if (bestSize <= 0) {
        await updateDownloadJobProgress(prisma, jobId, {
          status: "failed",
          processingStage: "failed",
          progress: null,
          error: LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE,
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
        notifyDownloadWorkerFailed({
          jobId,
          deviceId,
          url,
          platformLabel,
          classification: "output_empty",
          facebookDirectFallback: false,
          actionHint: "Download produced a zero-byte candidate file.",
        });
        return;
      }

      const sourceExt = path.extname(best).replace(/^\./, "") || "unknown";
      logDownloadPerf({
        stage: "ytdlp",
        durationMs: sourceDownloadTimer.elapsedMs(),
        jobId,
        platform: platformLabel,
        quality: format,
        formatSelector: facebookDirectFallback ? "facebook_direct" : primaryFormatStr,
        bytes: bestSize,
        ext: sourceExt,
        mime: mimeForExt(path.extname(best)),
        mergeLikely: facebookDirectFallback
          ? false
          : formatSelectorSuggestsMerge(primaryFormatStr),
        result: facebookDirectFallback ? "facebook_direct" : "ytdlp",
      });

      let assetFilename = best;
      let assetSize = bestSize;
      let mimeType = mimeForExt(path.extname(best));

      if (primaryBuilt.subdir === "videos") {
        if (isTikTokReady) {
          await updateDownloadJobProgress(
            prisma,
            jobId,
            { processingStage: "checking_compatibility", progress: null },
            {
              platform: platformLabel,
              requestedQuality: format,
              requestedFormat: format,
              normalizationEnabled: true,
              isTikTokReady: true,
            }
          );

          let probe: ProbeResult;
          try {
            probe = await ffprobeMedia(bestPath);
          } catch {
            logger.warn(
              {
                jobId,
                platform: platformLabel,
                quality: format,
                probeFailed: true,
                tiktokReadyCompatiblePreferred: true,
              },
              "ffprobe failed — using full transcode"
            );
            probe = { durationMs: 0 };
          }

          logger.info(
            {
              jobId,
              platform: platformLabel,
              quality: format,
              durationMs: probe.durationMs,
              videoCodec: probe.video?.codec,
              pixFmt: probe.video?.pixFmt,
              width: probe.video?.width,
              height: probe.video?.height,
              videoProfile: probe.video?.profile,
              audioCodec: probe.audio?.codec,
              audioProfile: probe.audio?.profile,
              formatName: probe.formatName,
              formatSelector: primaryFormatStr,
              tiktokReadyCompatiblePreferred: true,
              normalizationEnabled: true,
              isTikTokReady: true,
            },
            "ffprobe compatibility summary"
          );

          const strategy = selectNormalizeStrategy(probe);
          logger.info(
            {
              jobId,
              platform: platformLabel,
              quality: format,
              strategy,
              videoCodec: probe.video?.codec,
              audioCodec: probe.audio?.codec,
              width: probe.video?.width,
              height: probe.video?.height,
              tiktokReadyCompatiblePreferred: true,
              normalizationEnabled: true,
              normalizationStrategy: strategy,
              isTikTokReady: true,
            },
            "normalization strategy selected"
          );

          const ffmpegTimer = startPerfTimer();
          await updateDownloadJobProgress(
            prisma,
            jobId,
            { processingStage: stageForStrategy(strategy), progress: null },
            {
              platform: platformLabel,
              requestedQuality: format,
              requestedFormat: format,
              strategy,
              normalizationEnabled: true,
              isTikTokReady: true,
            }
          );

          const tmpName = `${jobId}-normalize-${randomBytes(8).toString("hex")}.tmp.mp4`;
          const tempNormPath = path.join(dir, tmpName);

          const throttle =
            strategy === "full_transcode"
              ? createProgressThrottler((pct) => {
                  void updateDownloadJobProgress(
                    prisma,
                    jobId,
                    { processingStage: "full_transcoding", progress: pct },
                    {
                      platform: platformLabel,
                      requestedQuality: format,
                      requestedFormat: format,
                      strategy,
                      normalizationEnabled: true,
                      isTikTokReady: true,
                      logMessage: "ffmpeg progress updated",
                    }
                  );
                })
              : null;

          let ffmpegResult: { code: number | null; stderrTail: string; args: string[] };
          if (strategy === "remux") {
            ffmpegResult = await runFfmpegRemux({ inputPath: bestPath, outputTempPath: tempNormPath });
          } else if (strategy === "audio_only") {
            ffmpegResult = await runFfmpegAudioNormalize({ inputPath: bestPath, outputTempPath: tempNormPath });
          } else {
            ffmpegResult = await runFfmpegFullTranscode({
              inputPath: bestPath,
              outputTempPath: tempNormPath,
              durationMs: probe.durationMs,
              onProgress: throttle ? (p) => throttle(p) : undefined,
            });
          }

          const ffmpegShape = ffmpegNormalizeCommandShape(ffmpegResult.args);

          let normStat: { size: number } | null = null;
          try {
            const st = await fs.stat(tempNormPath);
            normStat = { size: st.size };
          } catch {
            normStat = null;
          }
          const normalizedBytes = normStat?.size ?? 0;
          const normalizeOk = ffmpegResult.code === 0 && normalizedBytes > 0;

          if (!normalizeOk) {
            await fs.unlink(tempNormPath).catch(() => {});
            await updateDownloadJobProgress(
              prisma,
              jobId,
              {
                status: "failed",
                processingStage: "failed",
                progress: null,
                error: DOWNLOAD_JOB_ERROR_NORMALIZE_FAILED,
              },
              {
                platform: platformLabel,
                requestedQuality: format,
                requestedFormat: format,
                strategy,
                normalizationEnabled: true,
                isTikTokReady: true,
                logMessage: "download final status updated — normalize failed",
              }
            );
            logger.warn(
              {
                jobId,
                platform: platformLabel,
                quality: format,
                strategy,
                inputBytes: bestSize,
                outputBytes: normalizedBytes,
                outputExists: normalizedBytes > 0,
                ffmpegExitCode: ffmpegResult.code,
                success: false,
                normalizationEnabled: true,
                isTikTokReady: true,
                ...ffmpegShape,
              },
              "ffmpeg normalize failed"
            );
            notifyDownloadWorkerFailed({
              jobId,
              deviceId,
              url,
              platformLabel,
              classification: "tiktok_normalize_failed",
              facebookDirectFallback: false,
              actionHint: "TikTok-ready ffmpeg normalization failed — inspect ffmpeg logs.",
            });
            return;
          }

          await updateDownloadJobProgress(
            prisma,
            jobId,
            { processingStage: "finalizing", progress: null },
            {
              platform: platformLabel,
              requestedQuality: format,
              requestedFormat: format,
              strategy,
              normalizationEnabled: true,
              isTikTokReady: true,
              logMessage: "download stage updated — finalizing",
            }
          );

          const finalName = `${jobId}.mp4`;
          const finalPath = path.join(dir, finalName);
          for (const name of candidates) {
            await fs.unlink(path.join(dir, name)).catch(() => {});
          }

          try {
            await fs.rename(tempNormPath, finalPath);
          } catch (err) {
            await fs.unlink(tempNormPath).catch(() => {});
            await updateDownloadJobProgress(
              prisma,
              jobId,
              {
                status: "failed",
                processingStage: "failed",
                progress: null,
                error: DOWNLOAD_JOB_ERROR_NORMALIZE_FAILED,
              },
              {
                platform: platformLabel,
                requestedQuality: format,
                requestedFormat: format,
                strategy,
                normalizationEnabled: true,
                isTikTokReady: true,
              }
            );
            const errCode =
              err && typeof err === "object" && "code" in err
                ? String((err as { code?: unknown }).code ?? "")
                : "";
            logger.warn(
              {
                jobId,
                platform: platformLabel,
                quality: format,
                strategy,
                renameFailed: true,
                errCode: errCode || undefined,
                success: false,
                normalizationEnabled: true,
                isTikTokReady: true,
              },
              "ffmpeg normalize rename to final asset failed"
            );
            notifyDownloadWorkerFailed({
              jobId,
              deviceId,
              url,
              platformLabel,
              classification: "tiktok_finalize_rename_failed",
              facebookDirectFallback: false,
              actionHint: "Could not move normalized temp file into place.",
            });
            return;
          }

          let finalSize = normalizedBytes;
          try {
            finalSize = (await fs.stat(finalPath)).size;
          } catch {
            /* keep */
          }

          assetFilename = finalName;
          assetSize = finalSize;
          mimeType = "video/mp4";

          logger.info(
            {
              jobId,
              platform: platformLabel,
              quality: format,
              strategy,
              inputBytes: bestSize,
              outputBytes: finalSize,
              inputExists: true,
              outputExists: finalSize > 0,
              durationMs: probe.durationMs,
              ffmpegExitCode: ffmpegResult.code,
              success: true,
              normalizationEnabled: true,
              normalizationStrategy: strategy,
              isTikTokReady: true,
              tiktokReadyCompatiblePreferred: true,
              ...ffmpegShape,
            },
            "ffmpeg normalize succeeded"
          );
          logDownloadPerf({
            stage: "ffmpeg",
            durationMs: ffmpegTimer.elapsedMs(),
            jobId,
            platform: platformLabel,
            quality: format,
            strategy,
            bytes: finalSize,
            ext: "mp4",
            mime: "video/mp4",
            mediaDurationMs: probe.durationMs,
            result: "normalized",
          });
        } else {
          await updateDownloadJobProgress(
            prisma,
            jobId,
            { processingStage: "finalizing", progress: null },
            {
              platform: platformLabel,
              requestedQuality: format,
              requestedFormat: format,
              normalizationEnabled: false,
              isTikTokReady: false,
              logMessage: "download stage updated — finalizing (fast path)",
            }
          );
          logger.info(
            {
              jobId,
              platform: platformLabel,
              requestedFormat: format,
              normalizedFormat: format,
              isTikTokReady: false,
              normalizationEnabled: false,
              inputBytes: bestSize,
              outputFilename: assetFilename,
              mimeType,
            },
            "download fast path — ffmpeg normalization skipped"
          );
          logDownloadPerf({
            stage: "ffmpeg",
            durationMs: 0,
            jobId,
            platform: platformLabel,
            quality: format,
            strategy: "skipped",
            bytes: bestSize,
            result: "skipped",
          });
        }
      } else {
        await updateDownloadJobProgress(
          prisma,
          jobId,
          { processingStage: "finalizing", progress: null },
          { platform: platformLabel, requestedQuality: format, logMessage: "download stage updated — finalizing (audio)" }
        );
        logDownloadPerf({
          stage: "ffmpeg",
          durationMs: 0,
          jobId,
          platform: platformLabel,
          quality: format,
          strategy: "skipped",
          bytes: bestSize,
          result: "skipped_audio",
        });
      }

      const storageKey = path.posix.join("devices", deviceId, primaryBuilt.subdir, assetFilename);

      const createdAsset = await prisma.fileAsset.create({
        data: {
          deviceId,
          jobId,
          type: primaryBuilt.subdir === "videos" ? "video" : "audio",
          storageKey,
          filename: assetFilename,
          mimeType,
          sizeBytes: BigInt(assetSize),
        },
      });

      await updateDownloadJobProgress(
        prisma,
        jobId,
        {
          status: "done",
          processingStage: "done",
          progress: 100,
          speedText: null,
          etaText: null,
          error: null,
        },
        {
          platform: platformLabel,
          requestedQuality: format,
          requestedFormat: format,
          normalizationEnabled: isTikTokReady,
          isTikTokReady,
          logMessage: "download final status updated — done",
        }
      );

      logger.info(
        {
          jobId,
          platform: platformLabel,
          requestedFormat: format,
          requestedQuality: format,
          primaryYtDlpFormat: primaryFormatStr,
          fallbackAttempted,
          finalFormatString: finalFormatStr,
          outputFilename: assetFilename,
          outputBytes: assetSize,
          fileAssetId: createdAsset.id,
          finalStatus: "done",
          processingStage: "done",
          progressPercent: 100,
          normalizationEnabled: isTikTokReady,
          isTikTokReady,
        },
        "download completed"
      );

      const backendTotalMs = Math.max(0, Date.now() - jobCreatedAtMs);
      logDownloadPerf({
        stage: "running_to_done",
        durationMs: runningTimer.elapsedMs(),
        jobId,
        platform: platformLabel,
        quality: format,
        bytes: assetSize,
        mime: mimeType,
        ext: path.extname(assetFilename).replace(/^\./, "") || "unknown",
      });
      logDownloadPerf({
        stage: "backend_total",
        durationMs: backendTotalMs,
        jobId,
        platform: platformLabel,
        quality: format,
        bytes: assetSize,
        mime: mimeType,
        ext: path.extname(assetFilename).replace(/^\./, "") || "unknown",
        result: "done",
      });
    },
    {
      connection,
      concurrency: config.DOWNLOAD_CONCURRENCY,
    }
  );

  worker.on("failed", (job, err) => {
    logger.error({ jobId: job?.id, err }, "bullmq job failed");
    const data = job?.data as QueuePayload | undefined;
    if (data?.jobId && data.deviceId && data.url) {
      notifyDownloadWorkerBullUncaught({
        jobId: data.jobId,
        deviceId: data.deviceId,
        url: data.url,
      });
    }
  });

  return worker;
}
