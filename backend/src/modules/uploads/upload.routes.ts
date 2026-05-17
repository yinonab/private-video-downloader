import fs from "node:fs";
import fsp from "node:fs/promises";
import type { FastifyReply, FastifyRequest } from "fastify";
import { FastifyPluginAsync } from "fastify";
import { authDevice } from "../../middleware/authDevice";
import { resolveAbsoluteFromStorageKey } from "../../services/storage";
import { AppError, codes } from "../../types/errors";
import { getUploadedMediaForDevice, ingestDeviceVideoUpload } from "./upload.service";

async function streamStoredFile(
  request: FastifyRequest,
  reply: FastifyReply,
  storageKey: string,
  downloadFilename: string,
  mimeType: string,
  opts?: { inline?: boolean }
): Promise<void> {
  let absPath: string;
  try {
    absPath = resolveAbsoluteFromStorageKey(storageKey);
  } catch {
    throw new AppError(codes.UPLOAD_NOT_FOUND, "Upload file path invalid", 404);
  }

  let stat: fs.Stats;
  try {
    stat = await fsp.stat(absPath);
  } catch {
    throw new AppError(codes.UPLOAD_NOT_FOUND, "Upload file missing on disk", 404);
  }

  const size = stat.size;
  if (!stat.isFile() || size <= 0) {
    throw new AppError(codes.UPLOAD_NOT_FOUND, "Upload file missing or empty on disk", 404);
  }

  const range = request.headers.range;

  reply.header("Accept-Ranges", "bytes");
  reply.header("Content-Type", mimeType || "application/octet-stream");

  const safeName = downloadFilename.replace(/[^\w.\-]+/g, "_");
  reply.header(
    "Content-Disposition",
    opts?.inline ? `inline; filename="${safeName}"` : `attachment; filename="${safeName}"`
  );

  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/i.exec(range);
    if (!match) {
      reply.code(416);
      reply.header("Content-Range", `bytes */${size}`);
      await reply.send();
      return;
    }
    let start = match[1] ? Number(match[1]) : 0;
    let end = match[2] ? Number(match[2]) : size - 1;
    if (Number.isNaN(start) || Number.isNaN(end) || start > end || end >= size) {
      reply.code(416);
      reply.header("Content-Range", `bytes */${size}`);
      await reply.send();
      return;
    }
    const chunkSize = end - start + 1;
    reply.code(206);
    reply.header("Content-Range", `bytes ${start}-${end}/${size}`);
    reply.header("Content-Length", String(chunkSize));
    await reply.send(fs.createReadStream(absPath, { start, end }));
    return;
  }

  reply.header("Content-Length", String(size));
  await reply.send(fs.createReadStream(absPath));
}

const uploadRoutes: FastifyPluginAsync = async (app) => {
  app.post("/uploads/videos", { preHandler: authDevice }, async (request, reply) => {
    try {
      const part = await request.file();
      if (!part) {
        throw new AppError(codes.BAD_REQUEST, 'Missing multipart file field "file"', 400);
      }
      const ctx = request.deviceCtx!;
      const result = await ingestDeviceVideoUpload({
        prisma: app.prisma,
        deviceId: ctx.id,
        part,
        log: request.log,
      });
      reply.send(result);
    } catch (err) {
      if (err instanceof app.multipartErrors.RequestFileTooLargeError) {
        throw new AppError(codes.UPLOAD_FILE_TOO_LARGE, "File exceeds maximum upload size", 413);
      }
      throw err;
    }
  });

  app.get("/uploads/:id", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const uploadId = String((request.params as { id: string }).id ?? "");
    const row = await getUploadedMediaForDevice(app.prisma, ctx.id, uploadId);
    if (!row || row.status !== "ready") {
      throw new AppError(codes.UPLOAD_NOT_FOUND, "Upload not found", 404);
    }

    reply.send({
      uploadId: row.id,
      kind: row.kind,
      filename: row.originalFilename ?? null,
      mimeType: row.mimeType ?? null,
      sizeBytes: row.sizeBytes.toString(),
      durationSeconds: row.durationSeconds ?? null,
      width: row.width ?? null,
      height: row.height ?? null,
      thumbnailUrl: `/uploads/${row.id}/thumbnail`,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    });
  });

  app.get("/uploads/:id/file", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const uploadId = String((request.params as { id: string }).id ?? "");
    const row = await getUploadedMediaForDevice(app.prisma, ctx.id, uploadId);
    if (!row || row.status !== "ready") {
      throw new AppError(codes.UPLOAD_NOT_FOUND, "Upload not found", 404);
    }

    const base =
      row.originalFilename?.replace(/[^\w.\-]+/g, "_").replace(/^\./, "") || `upload-${row.id}`;
    const lower = base.toLowerCase();
    const withExt =
      lower.endsWith(".mp4") || lower.endsWith(".mov") || lower.endsWith(".webm")
        ? base
        : `${base}.mp4`;

    await streamStoredFile(
      request,
      reply,
      row.storageKey,
      withExt,
      row.mimeType ?? "application/octet-stream"
    );
  });

  app.get("/uploads/:id/thumbnail", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const uploadId = String((request.params as { id: string }).id ?? "");
    const row = await getUploadedMediaForDevice(app.prisma, ctx.id, uploadId);
    if (!row || row.status !== "ready") {
      throw new AppError(codes.UPLOAD_NOT_FOUND, "Upload not found", 404);
    }
    if (!row.thumbnailStorageKey) {
      throw new AppError(
        codes.UPLOAD_NOT_FOUND,
        "Thumbnail not available for this upload",
        404,
        "Thumbnail generation failed or is not present"
      );
    }

    await streamStoredFile(request, reply, row.thumbnailStorageKey, "thumbnail.jpg", "image/jpeg", {
      inline: true,
    });
  });
};

export default uploadRoutes;
