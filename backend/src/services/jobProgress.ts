import type { Prisma, PrismaClient } from "@prisma/client";
import { logger } from "./logger";

export type JobProgressPatch = {
  processingStage?: string | null;
  progress?: number | null;
  speedText?: string | null;
  etaText?: string | null;
  status?: string;
  error?: string | null;
};

/** Clamp progress for DB (null allowed). */
export function clampProgressPercent(v: number | null | undefined): number | null {
  if (v === null || v === undefined) return null;
  if (!Number.isFinite(v)) return null;
  return Math.max(0, Math.min(100, Math.round(v)));
}

export async function updateDownloadJobProgress(
  prisma: PrismaClient,
  jobId: string,
  patch: JobProgressPatch,
  logCtx?: {
    platform?: string;
    requestedQuality?: string;
    requestedFormat?: string;
    strategy?: string;
    logMessage?: string;
    normalizationEnabled?: boolean;
    isTikTokReady?: boolean;
  }
): Promise<void> {
  try {
    const prev = await prisma.downloadJob.findUnique({
      where: { id: jobId },
      select: { processingStage: true, status: true, progress: true },
    });

    const data: Prisma.DownloadJobUpdateInput = {};
    if (patch.processingStage !== undefined) data.processingStage = patch.processingStage;
    if (patch.progress !== undefined) data.progress = patch.progress;
    if (patch.speedText !== undefined) data.speedText = patch.speedText;
    if (patch.etaText !== undefined) data.etaText = patch.etaText;
    if (patch.status !== undefined) data.status = patch.status;
    if (patch.error !== undefined) data.error = patch.error;

    await prisma.downloadJob.update({ where: { id: jobId }, data });

    logger.info(
      {
        jobId,
        fromStage: prev?.processingStage,
        toStage: patch.processingStage ?? prev?.processingStage,
        progressPercent: patch.progress ?? prev?.progress,
        status: patch.status ?? prev?.status,
        platform: logCtx?.platform,
        requestedQuality: logCtx?.requestedQuality,
        requestedFormat: logCtx?.requestedFormat ?? logCtx?.requestedQuality,
        strategy: logCtx?.strategy,
        normalizationEnabled: logCtx?.normalizationEnabled,
        isTikTokReady: logCtx?.isTikTokReady,
      },
      logCtx?.logMessage ?? "download stage updated"
    );
  } catch (err) {
    logger.warn({ jobId, err, patch }, "download stage update failed");
  }
}

/** Throttle ffmpeg phase progress DB writes: ≤1/s and ≥2% change. */
export function createProgressThrottler(onEmit: (pct: number) => void): (pct0to100: number) => void {
  let lastTs = 0;
  let lastPct = -999;
  return (raw: number) => {
    const clamped = Math.max(0, Math.min(99, Math.floor(raw)));
    const now = Date.now();
    if (now - lastTs < 1000 && Math.abs(clamped - lastPct) < 2) return;
    lastTs = now;
    lastPct = clamped;
    onEmit(clamped);
  };
}
