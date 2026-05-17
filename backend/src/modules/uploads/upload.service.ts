import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { createWriteStream } from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { Readable } from "node:stream";
import { finished } from "node:stream/promises";
import type { MultipartFile } from "@fastify/multipart";
import type { PrismaClient } from "@prisma/client";
import type { FastifyBaseLogger } from "fastify";
import { config } from "../../config";
import { ffprobeMedia } from "../../services/ffmpegNormalize";
import {
  getUploadDir,
  uploadSourceStorageKey,
  uploadThumbnailStorageKey,
} from "../../services/storage";
import { AppError, codes } from "../../types/errors";

export type VideoUploadResult = {
  uploadId: string;
  kind: "video";
  filename: string | null;
  mimeType: string | null;
  sizeBytes: string;
  durationSeconds: number;
  width: number;
  height: number;
  thumbnailUrl: string;
};

const ALLOWED_DECLARED_MIME = new Set(["video/mp4", "video/quicktime", "video/webm"]);

function assertDeclarableMime(mimetype: string | undefined): void {
  const raw = (mimetype ?? "").trim().toLowerCase();
  if (!raw || raw === "application/octet-stream") return;
  if (!ALLOWED_DECLARED_MIME.has(raw)) {
    throw new AppError(
      codes.UPLOAD_UNSUPPORTED_TYPE,
      "Unsupported Content-Type for video upload",
      415,
      "Allowed types: video/mp4, video/quicktime, video/webm (or application/octet-stream)"
    );
  }
}

function parseFormatParts(formatName: string | undefined): string[] {
  if (!formatName?.trim()) return [];
  return formatName
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

/** Enforce MVP containers matching declared MIME policy (mp4/mov/webm), using ffprobe ids. */
function assertAllowedContainer(formatName: string | undefined): void {
  const parts = parseFormatParts(formatName);
  if (!parts.length) {
    throw new AppError(codes.UPLOAD_INVALID_VIDEO, "Missing container metadata", 400);
  }

  const hasWebmToken = parts.some((p) => p === "webm");
  const hasMatroska = parts.some((p) => p === "matroska");
  if (hasMatroska && !hasWebmToken) {
    throw new AppError(
      codes.UPLOAD_UNSUPPORTED_TYPE,
      "Unsupported container (Matroska/WebM required for webm)",
      415
    );
  }
  if (hasWebmToken) return;

  const mp4Family = new Set(["mov", "mp4", "m4v", "isom", "iso2", "3gp", "3g2", "mj2"]);
  if (parts.some((p) => mp4Family.has(p))) return;

  throw new AppError(codes.UPLOAD_UNSUPPORTED_TYPE, "Unsupported video container", 415);
}

function normalizedMimeFromProbe(formatName: string): string {
  const parts = parseFormatParts(formatName);
  if (parts.some((p) => p === "webm")) return "video/webm";
  const hasMov = parts.includes("mov");
  const hasMp4ish = parts.some((p) =>
    ["mp4", "isom", "iso2", "m4v", "3gp", "3g2", "mj2"].includes(p)
  );
  if (hasMov && !hasMp4ish) return "video/quicktime";
  return "video/mp4";
}

function pickSourceExtension(formatName: string): string {
  const parts = parseFormatParts(formatName);
  if (parts.some((p) => p === "webm")) return "webm";
  const hasMov = parts.includes("mov");
  const hasMp4ish = parts.some((p) =>
    ["mp4", "isom", "iso2", "m4v", "3gp", "3g2", "mj2"].includes(p)
  );
  if (hasMov && !hasMp4ish) return "mov";
  return "mp4";
}

async function drainStreamToFileWithLimit(
  stream: Readable,
  destPath: string,
  maxBytes: number
): Promise<number> {
  const ws = createWriteStream(destPath);
  let written = 0;
  try {
    for await (const chunk of stream) {
      const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      written += buf.length;
      if (written > maxBytes) {
        throw new AppError(codes.UPLOAD_FILE_TOO_LARGE, "File exceeds maximum upload size", 413);
      }
      if (!ws.write(buf)) {
        await new Promise<void>((resolve, reject) => {
          ws.once("drain", resolve);
          ws.once("error", reject);
        });
      }
    }
    ws.end();
    await finished(ws);
    return written;
  } catch (e) {
    ws.destroy();
    throw e;
  }
}

async function moveOntoFinalPath(tmpFile: string, finalPath: string): Promise<void> {
  await fsp.mkdir(path.dirname(finalPath), { recursive: true });
  try {
    await fsp.rename(tmpFile, finalPath);
  } catch {
    await fsp.copyFile(tmpFile, finalPath);
    await fsp.unlink(tmpFile).catch(() => undefined);
  }
}

async function tryGenerateThumbnail(
  videoPath: string,
  outPath: string,
  durationSeconds: number
): Promise<boolean> {
  const ss = durationSeconds >= 1 ? 1 : Math.max(0, Number((durationSeconds / 2).toFixed(3)));
  const args = [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-ss",
    String(ss),
    "-i",
    videoPath,
    "-frames:v",
    "1",
    "-q:v",
    "3",
    outPath,
  ];
  const code = await new Promise<number | null>((resolve) => {
    const c = spawn("ffmpeg", args, { stdio: "ignore" });
    c.on("error", () => resolve(null));
    c.on("close", resolve);
  });
  if (code !== 0) return false;
  try {
    const st = await fsp.stat(outPath);
    return st.isFile() && st.size > 0;
  } catch {
    return false;
  }
}

async function rmTreeQuiet(dir: string): Promise<void> {
  await fsp.rm(dir, { recursive: true, force: true }).catch(() => undefined);
}

export async function ingestDeviceVideoUpload(params: {
  prisma: PrismaClient;
  deviceId: string;
  part: MultipartFile;
  log: FastifyBaseLogger;
}): Promise<VideoUploadResult> {
  const { prisma, deviceId, part, log } = params;

  if (part.fieldname !== "file") {
    throw new AppError(codes.BAD_REQUEST, 'Expected multipart field name "file"', 400);
  }

  assertDeclarableMime(part.mimetype);

  const uploadId = randomUUID();
  const tmpRoot = await fsp.mkdtemp(path.join(os.tmpdir(), "linkclip-ul-"));
  const tmpFile = path.join(tmpRoot, "part.bin");
  let uploadDirForRollback: string | null = null;

  try {
    const maxBytes = config.maxLocalVideoUploadBytes;
    const written = await drainStreamToFileWithLimit(part.file, tmpFile, maxBytes);

    if (written <= 0) {
      throw new AppError(codes.UPLOAD_INVALID_VIDEO, "Empty upload", 400);
    }

    let probe;
    try {
      probe = await ffprobeMedia(tmpFile);
    } catch (err) {
      log.warn({ err, uploadId }, "upload ffprobe failed");
      throw new AppError(codes.UPLOAD_INVALID_VIDEO, "Could not read video metadata", 400);
    }

    if (!probe.video) {
      throw new AppError(codes.UPLOAD_INVALID_VIDEO, "No video stream", 400);
    }

    assertAllowedContainer(probe.formatName);

    if (!probe.durationMs || probe.durationMs <= 0) {
      throw new AppError(codes.UPLOAD_INVALID_VIDEO, "Could not determine duration", 400);
    }

    const durationSecondsCeil = Math.max(1, Math.ceil(probe.durationMs / 1000));
    if (durationSecondsCeil > config.maxLocalVideoUploadDurationSeconds) {
      throw new AppError(codes.UPLOAD_VIDEO_TOO_LONG, "Video exceeds maximum duration", 400);
    }

    const w = probe.video.width;
    const h = probe.video.height;
    if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0) {
      throw new AppError(codes.UPLOAD_INVALID_VIDEO, "Invalid video dimensions", 400);
    }

    const ext = pickSourceExtension(probe.formatName ?? "");
    const mimeStored = normalizedMimeFromProbe(probe.formatName ?? "");

    const uploadDir = getUploadDir(deviceId, uploadId);
    const finalVideoPath = path.join(uploadDir, `source.${ext}`);
    const thumbPath = path.join(uploadDir, "thumbnail.jpg");

    await moveOntoFinalPath(tmpFile, finalVideoPath);
    uploadDirForRollback = uploadDir;

    const storageKey = uploadSourceStorageKey(deviceId, uploadId, ext);
    const thumbKeyRel = uploadThumbnailStorageKey(deviceId, uploadId);

    let thumbnailStorageKey: string | null = null;
    const thumbOk = await tryGenerateThumbnail(finalVideoPath, thumbPath, durationSecondsCeil);
    if (thumbOk) {
      thumbnailStorageKey = thumbKeyRel;
    } else {
      log.warn({ uploadId }, "upload thumbnail generation skipped or failed; continuing without thumbnail");
    }

    const originalName =
      part.filename && part.filename.trim() !== "" ? path.basename(part.filename) : null;

    try {
      await prisma.uploadedMedia.create({
        data: {
          id: uploadId,
          deviceId,
          kind: "video",
          originalFilename: originalName,
          mimeType: mimeStored,
          sizeBytes: BigInt(written),
          storageKey,
          durationSeconds: durationSecondsCeil,
          width: Math.round(w),
          height: Math.round(h),
          thumbnailStorageKey,
          status: "ready",
        },
      });
    } catch (err) {
      log.error({ err, uploadId }, "upload prisma create failed");
      throw new AppError(codes.UPLOAD_FAILED, "Could not persist upload metadata", 500);
    }

    uploadDirForRollback = null;

    return {
      uploadId,
      kind: "video",
      filename: originalName,
      mimeType: mimeStored,
      sizeBytes: written.toString(),
      durationSeconds: durationSecondsCeil,
      width: Math.round(w),
      height: Math.round(h),
      thumbnailUrl: `/uploads/${uploadId}/thumbnail`,
    };
  } catch (e) {
    if (e instanceof AppError) throw e;
    log.error({ err: e, uploadId }, "upload failed unexpectedly");
    throw new AppError(codes.UPLOAD_FAILED, "Upload failed", 500);
  } finally {
    if (uploadDirForRollback) {
      await rmTreeQuiet(uploadDirForRollback);
    }
    await rmTreeQuiet(tmpRoot);
  }
}

export async function getUploadedMediaForDevice(
  prisma: PrismaClient,
  deviceId: string,
  uploadId: string
) {
  return prisma.uploadedMedia.findFirst({
    where: { id: uploadId, deviceId },
  });
}
