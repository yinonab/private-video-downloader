import type { FileAsset, PrismaClient } from "@prisma/client";
import type { Queue } from "bullmq";
import type Redis from "ioredis";
import { AppError, codes } from "../../types/errors";
import { hashUrl } from "../../services/hashing";
import { assertUrlSafeForFetch, normalizeUrl } from "../../services/urlSafety";
import type { DownloadFormatKind } from "../../services/ytdlp";
import {
  assertUnderDailyDownloadLimit,
  incrementDailyDownloadCount,
} from "../../services/rateLimit";
import { deleteJobFilesFromDisk } from "../../services/storage";
import type { CreateDownloadBody } from "./download.schemas";
import { logger } from "../../services/logger";

export type QueuePayload = {
  jobId: string;
  deviceId: string;
  url: string;
  format: DownloadFormatKind;
};

const ALLOWED = new Set<string>(["best", "1080p", "720p", "480p", "audio_mp3"]);

/** Strip bidi / invisible chars; lowercase (fixes rare client RTL/zero-width pollution). */
export function sanitizeQualityToken(raw: string): string {
  return raw
    .replace(/[\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, "")
    .trim()
    .toLowerCase();
}

export function resolveFormat(body: CreateDownloadBody): DownloadFormatKind {
  let fmt = sanitizeQualityToken(body.format);
  const qRaw = body.quality;
  let q = qRaw != null && qRaw !== "" ? sanitizeQualityToken(qRaw) : "";
  if (fmt === "audio") fmt = "audio_mp3";
  if (q === "audio") q = "audio_mp3";
  if (!fmt && q) fmt = q;
  if (!ALLOWED.has(fmt)) {
    throw new AppError(codes.UNSUPPORTED_QUALITY, "Unsupported format", 400);
  }
  return fmt as DownloadFormatKind;
}

export function storagePair(kind: DownloadFormatKind): { format: string; quality: string } {
  const quality = kind === "audio_mp3" ? "audio_mp3" : kind === "best" ? "best" : kind;
  return { format: kind, quality };
}

export async function createDownload(opts: {
  prisma: PrismaClient;
  redis: Redis;
  queue: Queue;
  deviceId: string;
  dailyLimit: number;
  body: CreateDownloadBody;
}): Promise<{ jobId: string; status: string; cached: boolean }> {
  let normalized: string;
  try {
    normalized = normalizeUrl(opts.body.url);
  } catch (e) {
    if (e instanceof AppError) throw e;
    throw new AppError(codes.INVALID_URL, "Invalid URL", 400);
  }

  await assertUrlSafeForFetch(normalized);

  const urlHash = hashUrl(normalized);
  let kind: DownloadFormatKind;
  try {
    kind = resolveFormat(opts.body);
  } catch (e) {
    logger.warn(
      {
        downloadFormatNormalize: true,
        accepted: false,
        formatReceived: opts.body.format,
        qualityReceived: opts.body.quality,
        err: e instanceof Error ? e.message : String(e),
      },
      "POST /downloads format rejected"
    );
    throw e;
  }
  logger.info(
    {
      downloadFormatNormalize: true,
      accepted: true,
      normalizedFormat: kind,
      formatReceived: opts.body.format,
      qualityReceived: opts.body.quality,
    },
    "POST /downloads format accepted"
  );
  const pair = storagePair(kind);

  const concurrent = await opts.prisma.downloadJob.count({
    where: {
      deviceId: opts.deviceId,
      status: { in: ["queued", "running"] },
    },
  });
  if (concurrent >= 1) {
    throw new AppError(codes.CONFLICT, "Another download is already in progress", 409);
  }

  await assertUnderDailyDownloadLimit(opts.redis, opts.deviceId, opts.dailyLimit);

  let link = await opts.prisma.link.findUnique({ where: { urlHash } });

  if (link) {
    const cached = await opts.prisma.downloadJob.findFirst({
      where: {
        deviceId: opts.deviceId,
        linkId: link.id,
        format: pair.format,
        quality: pair.quality,
        status: "done",
      },
      include: { files: true },
      orderBy: { createdAt: "desc" },
    });
  const primary =
      cached?.files.find((f: FileAsset) => f.type === "video") ??
      cached?.files.find((f: FileAsset) => f.type === "audio");
    if (cached && primary) {
      logger.info({ jobId: cached.id, deviceId: opts.deviceId }, "download cache hit");
      return { jobId: cached.id, status: "done", cached: true };
    }
  }

  link = await opts.prisma.link.upsert({
    where: { urlHash },
    create: {
      url: normalized,
      urlHash,
    },
    update: {
      url: normalized,
    },
  });

  const job = await opts.prisma.downloadJob.create({
    data: {
      deviceId: opts.deviceId,
      linkId: link.id,
      status: "queued",
      format: pair.format,
      quality: pair.quality,
    },
  });

  await incrementDailyDownloadCount(opts.redis, opts.deviceId);

  await opts.queue.add(
    job.id,
    {
      jobId: job.id,
      deviceId: opts.deviceId,
      url: normalized,
      format: kind,
    } satisfies QueuePayload,
    { jobId: job.id, attempts: 1, removeOnComplete: true, removeOnFail: false }
  );

  logger.info({ jobId: job.id, deviceId: opts.deviceId }, "download queued");

  return { jobId: job.id, status: "queued", cached: false };
}

export async function getDownloadForDevice(
  prisma: PrismaClient,
  deviceId: string,
  jobId: string
) {
  const job = await prisma.downloadJob.findFirst({
    where: { id: jobId, deviceId },
    include: {
      link: true,
      files: true,
    },
  });
  if (!job) {
    throw new AppError(codes.JOB_NOT_FOUND, "Job not found", 404);
  }

  const primary =
    job.files.find((f: FileAsset) => f.type === "video") ?? job.files.find((f: FileAsset) => f.type === "audio");

  return {
    id: job.id,
    status: job.status,
    progress: job.progress,
    speedText: job.speedText,
    etaText: job.etaText,
    title: job.link.title ?? undefined,
    thumbnail: job.link.thumbnail ?? undefined,
    error: job.error ?? undefined,
    file:
      job.status === "done" && primary
        ? {
            id: primary.id,
            filename: primary.filename,
            mimeType: primary.mimeType ?? undefined,
            sizeBytes: primary.sizeBytes != null ? Number(primary.sizeBytes) : undefined,
            downloadUrl: `/downloads/${job.id}/file`,
          }
        : null,
  };
}

export async function listDownloadsForDevice(
  prisma: PrismaClient,
  deviceId: string,
  query: { page: number; limit: number; status?: string; platform?: string }
) {
  const where = {
    deviceId,
    ...(query.status ? { status: query.status } : {}),
    ...(query.platform
      ? {
          link: {
            OR: [
              { platform: query.platform },
              { extractor: { contains: query.platform, mode: "insensitive" as const } },
            ],
          },
        }
      : {}),
  };

  const skip = (query.page - 1) * query.limit;

  const [total, rows] = await prisma.$transaction([
    prisma.downloadJob.count({ where }),
    prisma.downloadJob.findMany({
      where,
      include: { link: true, files: true },
      orderBy: { createdAt: "desc" },
      skip,
      take: query.limit,
    }),
  ]);

  const items = rows.map((job: (typeof rows)[number]) => {
    const primary =
      job.files.find((f: FileAsset) => f.type === "video") ??
      job.files.find((f: FileAsset) => f.type === "audio");
    return {
      id: job.id,
      status: job.status,
      title: job.link.title ?? "Untitled",
      platform: job.link.platform ?? job.link.extractor ?? "unknown",
      thumbnail: job.link.thumbnail ?? undefined,
      createdAt: job.createdAt.toISOString(),
      progress: job.progress,
      speedText: job.speedText ?? undefined,
      etaText: job.etaText ?? undefined,
      error: job.error ?? undefined,
      file:
        primary && job.status === "done"
          ? {
              filename: primary.filename,
              sizeBytes: primary.sizeBytes != null ? Number(primary.sizeBytes) : undefined,
              mimeType: primary.mimeType ?? undefined,
              downloadUrl: `/downloads/${job.id}/file`,
            }
          : undefined,
    };
  });

  return { items, page: query.page, limit: query.limit, total };
}

export async function retryDownload(opts: {
  prisma: PrismaClient;
  queue: Queue;
  deviceId: string;
  jobId: string;
}): Promise<{ jobId: string; status: string }> {
  const job = await opts.prisma.downloadJob.findFirst({
    where: { id: opts.jobId, deviceId: opts.deviceId },
    include: { link: true },
  });
  if (!job) {
    throw new AppError(codes.JOB_NOT_FOUND, "Job not found", 404);
  }
  if (!["failed", "canceled"].includes(job.status)) {
    throw new AppError(codes.BAD_REQUEST, "Only failed or canceled jobs can be retried", 400);
  }

  const fmt = sanitizeQualityToken(job.format ?? "best");
  if (!ALLOWED.has(fmt)) {
    throw new AppError(codes.UNSUPPORTED_QUALITY, "Stored format is invalid", 400);
  }
  const kind = fmt as DownloadFormatKind;

  await opts.prisma.downloadJob.update({
    where: { id: job.id },
    data: {
      status: "queued",
      progress: 0,
      error: null,
      speedText: null,
      etaText: null,
    },
  });

  await opts.queue.add(
    job.id,
    {
      jobId: job.id,
      deviceId: opts.deviceId,
      url: job.link.url,
      format: kind,
    } satisfies QueuePayload,
    { jobId: job.id, attempts: 1, removeOnComplete: true, removeOnFail: false }
  );

  logger.info({ jobId: job.id }, "download retry queued");

  return { jobId: job.id, status: "queued" };
}

export async function deleteDownload(opts: {
  prisma: PrismaClient;
  deviceId: string;
  jobId: string;
}): Promise<void> {
  const job = await opts.prisma.downloadJob.findFirst({
    where: { id: opts.jobId, deviceId: opts.deviceId },
  });
  if (!job) {
    throw new AppError(codes.JOB_NOT_FOUND, "Job not found", 404);
  }

  await deleteJobFilesFromDisk(opts.deviceId, opts.jobId);
  await opts.prisma.downloadJob.delete({ where: { id: job.id } });

  logger.info({ jobId: job.id }, "download deleted");
}
