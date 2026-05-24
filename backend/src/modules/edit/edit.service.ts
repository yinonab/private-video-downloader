import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import type { EditJob, FileAsset, Prisma, PrismaClient } from "@prisma/client";
import type { Queue } from "bullmq";
import { AppError, codes } from "../../types/errors";
import { resolveAbsoluteFromStorageKey } from "../../services/storage";
import { logger } from "../../services/logger";
import {
  createEditJobSchema,
  editOperationSchema,
  unsupportedFormatModeErrorFromUnknownBody,
  unsupportedSpeedFactorErrorFromUnknownBody,
  type EditOperation,
} from "./edit.schemas";
import type { EditQueuePayload } from "./edit.types";
import { z } from "zod";

type VideoPick = {
  asset: FileAsset;
  absPath: string;
  stat: fs.Stats;
};

async function pickDoneVideoFile(files: FileAsset[]): Promise<VideoPick | null> {
  const videos = files.filter((f) => f.type === "video");
  const picks: VideoPick[] = [];

  for (const asset of videos) {
    let absPath: string;
    try {
      absPath = resolveAbsoluteFromStorageKey(asset.storageKey);
    } catch {
      continue;
    }
    let st: fs.Stats;
    try {
      st = await fsp.stat(absPath);
    } catch {
      continue;
    }
    if (!st.isFile() || st.size <= 0) continue;
    picks.push({ asset, absPath, stat: st });
  }

  if (!picks.length) return null;

  picks.sort((a, b) => Number(b.stat.size - a.stat.size));
  return picks[0]!;
}

export async function assertDownloadVideoSourceReady(opts: {
  prisma: PrismaClient;
  deviceId: string;
  sourceDownloadJobId: string;
  log?: { editJobId?: string };
}): Promise<VideoPick> {
  const job = await opts.prisma.downloadJob.findFirst({
    where: { id: opts.sourceDownloadJobId, deviceId: opts.deviceId },
    include: { files: true },
  });
  if (!job) {
    throw new AppError(codes.JOB_NOT_FOUND, "Source download job not found", 404);
  }
  if (job.status !== "done") {
    throw new AppError(codes.EDIT_INVALID_SOURCE, "Source download is not completed", 400);
  }

  const picked = await pickDoneVideoFile(job.files);
  if (!picked) {
    throw new AppError(
      codes.EDIT_INVALID_SOURCE,
      "No completed video file on disk for this download",
      400,
      "Requires a non-empty video FileAsset"
    );
  }

  logger.info(
    {
      sourceDownloadJobId: opts.sourceDownloadJobId,
      deviceId: opts.deviceId,
      editJobId: opts.log?.editJobId,
      pickedStorageKey: picked.asset.storageKey,
      pickedSizeBytes: picked.stat.size,
    },
    "edit source validated"
  );

  return picked;
}

export type ResolvedEditSource = {
  absPath: string;
  sourceKind: "download" | "upload";
  durationSeconds?: number;
  width?: number;
  height?: number;
};

/** Resolve absolute source path for an edit job (download FileAsset or UploadedMedia). */
export async function resolveEditSource(opts: {
  prisma: PrismaClient;
  row: EditJob;
  deviceId: string;
  log?: { editJobId?: string };
}): Promise<ResolvedEditSource> {
  const { prisma, row, deviceId, log } = opts;

  const dlId = row.sourceDownloadJobId;
  const upId = row.sourceUploadId;
  const hasDl = dlId != null && dlId !== "";
  const hasUp = upId != null && upId !== "";

  if (!hasDl && !hasUp) {
    throw new AppError(codes.EDIT_FAILED, "Edit job has no source reference", 500);
  }
  if (hasDl && hasUp) {
    throw new AppError(codes.EDIT_FAILED, "Edit job has ambiguous source references", 500);
  }

  if (hasDl) {
    const picked = await assertDownloadVideoSourceReady({
      prisma,
      deviceId,
      sourceDownloadJobId: dlId!,
      log,
    });
    return { absPath: picked.absPath, sourceKind: "download" };
  }

  const uploadPick = await assertUploadVideoSourceReady({
    prisma,
    deviceId,
    sourceUploadId: upId!,
    log,
  });

  return {
    absPath: uploadPick.absPath,
    sourceKind: "upload",
    durationSeconds: uploadPick.durationSeconds ?? undefined,
    width: uploadPick.width ?? undefined,
    height: uploadPick.height ?? undefined,
  };
}

export async function assertUploadVideoSourceReady(opts: {
  prisma: PrismaClient;
  deviceId: string;
  sourceUploadId: string;
  log?: { editJobId?: string };
}): Promise<{
  absPath: string;
  stat: fs.Stats;
  storageKey: string;
  durationSeconds: number | null;
  width: number | null;
  height: number | null;
}> {
  const upload = await opts.prisma.uploadedMedia.findFirst({
    where: { id: opts.sourceUploadId, deviceId: opts.deviceId },
  });
  if (!upload) {
    throw new AppError(codes.EDIT_UPLOAD_NOT_FOUND, "Uploaded source not found", 404);
  }
  if (upload.kind !== "video") {
    throw new AppError(codes.EDIT_UPLOAD_NOT_READY, "Uploaded source is not a video", 400);
  }
  if (upload.status !== "ready") {
    throw new AppError(codes.EDIT_UPLOAD_NOT_READY, "Uploaded source is not ready", 400);
  }

  let absPath: string;
  try {
    absPath = resolveAbsoluteFromStorageKey(upload.storageKey);
  } catch {
    throw new AppError(
      codes.EDIT_SOURCE_FILE_MISSING,
      "Uploaded source storage key is invalid",
      400
    );
  }

  let st: fs.Stats;
  try {
    st = await fsp.stat(absPath);
  } catch {
    throw new AppError(codes.EDIT_SOURCE_FILE_MISSING, "Uploaded source file missing on disk", 400);
  }
  if (!st.isFile() || st.size <= 0) {
    throw new AppError(codes.EDIT_SOURCE_FILE_MISSING, "Uploaded source file is missing or empty", 400);
  }

  logger.info(
    {
      sourceUploadId: opts.sourceUploadId,
      deviceId: opts.deviceId,
      editJobId: opts.log?.editJobId,
      pickedStorageKey: upload.storageKey,
      pickedSizeBytes: st.size,
    },
    "edit upload source validated"
  );

  return {
    absPath,
    stat: st,
    storageKey: upload.storageKey,
    durationSeconds: upload.durationSeconds,
    width: upload.width,
    height: upload.height,
  };
}

export async function createEditJob(opts: {
  prisma: PrismaClient;
  queue: Queue;
  deviceId: string;
  body: unknown;
}): Promise<{ editJobId: string; status: string }> {
  const parsed = createEditJobSchema.safeParse(opts.body);
  if (!parsed.success) {
    const speedOnly = unsupportedSpeedFactorErrorFromUnknownBody(opts.body);
    if (speedOnly != null) throw speedOnly;
    const formatOnly = unsupportedFormatModeErrorFromUnknownBody(opts.body);
    if (formatOnly != null) throw formatOnly;
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
    throw new AppError(
      codes.EDIT_MULTIPLE_SOURCES,
      "Provide only one of sourceDownloadJobId or sourceUploadId",
      400
    );
  }

  if (hasDl) {
    await assertDownloadVideoSourceReady({
      prisma: opts.prisma,
      deviceId: opts.deviceId,
      sourceDownloadJobId: d.sourceDownloadJobId!,
    });
  } else {
    await assertUploadVideoSourceReady({
      prisma: opts.prisma,
      deviceId: opts.deviceId,
      sourceUploadId: d.sourceUploadId!,
    });
  }

  const operationsJson = d.operations as unknown as Prisma.InputJsonValue;

  const row = await opts.prisma.editJob.create({
    data: {
      deviceId: opts.deviceId,
      sourceDownloadJobId: hasDl ? d.sourceDownloadJobId! : null,
      sourceUploadId: hasUp ? d.sourceUploadId! : null,
      status: "queued",
      stage: "queued",
      progressPercent: null,
      operationsJson,
    },
  });

  const payload: EditQueuePayload = { editJobId: row.id, deviceId: opts.deviceId };
  await opts.queue.add(row.id, payload, {
    jobId: row.id,
    attempts: 1,
    removeOnComplete: true,
    removeOnFail: false,
  });

  logger.info(
    {
      editJobId: row.id,
      deviceId: opts.deviceId,
      ...(hasDl ? { sourceDownloadJobId: d.sourceDownloadJobId } : {}),
      ...(hasUp ? { sourceUploadId: d.sourceUploadId } : {}),
    },
    "edit job created"
  );

  return { editJobId: row.id, status: "queued" };
}

export function parseStoredOperations(json: Prisma.JsonValue): EditOperation[] {
  const parsed = z.array(editOperationSchema).safeParse(json);
  if (!parsed.success) {
    throw new Error("stored operations invalid");
  }
  return parsed.data;
}

export async function getEditJobForDevice(opts: {
  prisma: PrismaClient;
  deviceId: string;
  editJobId: string;
}) {
  const row = await opts.prisma.editJob.findFirst({
    where: { id: opts.editJobId, deviceId: opts.deviceId },
  });
  if (!row) {
    throw new AppError(codes.EDIT_JOB_NOT_FOUND, "Edit job not found", 404);
  }

  const hasUp = row.sourceUploadId != null && row.sourceUploadId !== "";
  const hasDl = row.sourceDownloadJobId != null && row.sourceDownloadJobId !== "";
  const sourceKind: "download" | "upload" | undefined = hasUp ? "upload" : hasDl ? "download" : undefined;

  return {
    id: row.id,
    status: row.status,
    stage: row.stage ?? undefined,
    progressPercent: row.progressPercent ?? undefined,
    sourceDownloadJobId: row.sourceDownloadJobId ?? undefined,
    sourceUploadId: row.sourceUploadId ?? undefined,
    ...(sourceKind != null ? { sourceKind } : {}),
    outputReady: row.status === "done" && row.outputStorageKey != null && row.outputStorageKey !== "",
    outputFilename: row.outputFilename ?? undefined,
    outputMimeType: row.outputMimeType ?? undefined,
    outputSizeBytes: row.outputSizeBytes != null ? Number(row.outputSizeBytes) : undefined,
    errorCode: row.errorCode ?? undefined,
    errorMessage: row.errorMessage ?? undefined,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    completedAt: row.completedAt?.toISOString(),
    fileUrl: row.status === "done" ? `/edits/${row.id}/file` : undefined,
  };
}

export async function retryEditJob(opts: {
  prisma: PrismaClient;
  queue: Queue;
  deviceId: string;
  editJobId: string;
}): Promise<{ editJobId: string; status: string }> {
  const row = await opts.prisma.editJob.findFirst({
    where: { id: opts.editJobId, deviceId: opts.deviceId },
  });
  if (!row) {
    throw new AppError(codes.EDIT_JOB_NOT_FOUND, "Edit job not found", 404);
  }
  if (row.status !== "failed") {
    throw new AppError(codes.BAD_REQUEST, "Only failed edit jobs can be retried", 400);
  }

  if (row.outputStorageKey) {
    try {
      const abs = resolveAbsoluteFromStorageKey(row.outputStorageKey);
      await fsp.unlink(abs).catch(() => undefined);
    } catch {
      /* ignore */
    }
  }

  await opts.prisma.editJob.update({
    where: { id: row.id },
    data: {
      status: "queued",
      stage: "queued",
      progressPercent: null,
      outputStorageKey: null,
      outputFilename: null,
      outputMimeType: null,
      outputSizeBytes: null,
      errorCode: null,
      errorMessage: null,
      completedAt: null,
    },
  });

  const payload: EditQueuePayload = { editJobId: row.id, deviceId: opts.deviceId };
  await opts.queue.add(row.id, payload, {
    jobId: row.id,
    attempts: 1,
    removeOnComplete: true,
    removeOnFail: false,
  });

  logger.info({ editJobId: row.id, deviceId: opts.deviceId }, "edit job retry queued");

  return { editJobId: row.id, status: "queued" };
}

export function expectedEditOutputStorageKey(deviceId: string, editJobId: string): string {
  return path.posix.join("devices", deviceId, "edits", `${editJobId}.mp4`);
}
