import fs from "node:fs";
import fsp from "node:fs/promises";
import type { FastifyReply, FastifyRequest } from "fastify";
import { FastifyPluginAsync } from "fastify";
import { authDevice } from "../../middleware/authDevice";
import { resolveAbsoluteFromStorageKey } from "../../services/storage";
import { createDownloadSchema, listDownloadsQuerySchema } from "./download.schemas";
import {
  createDownload,
  deleteDownload,
  getDownloadForDevice,
  listDownloadsForDevice,
  retryDownload,
} from "./download.service";
import { AppError, codes } from "../../types/errors";
import type { FileAsset } from "@prisma/client";

async function streamAssetFile(
  request: FastifyRequest,
  reply: FastifyReply,
  absPath: string,
  filename: string,
  mimeType: string
): Promise<void> {
  let stat;
  try {
    stat = await fsp.stat(absPath);
  } catch {
    throw new AppError(codes.FILE_NOT_FOUND, "File not found", 404);
  }

  const size = stat.size;
  const range = request.headers.range;

  reply.header("Accept-Ranges", "bytes");
  reply.header("Content-Type", mimeType || "application/octet-stream");

  const safeName = filename.replace(/[^\w.\-]+/g, "_");
  reply.header("Content-Disposition", `attachment; filename="${safeName}"`);

  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/i.exec(range);
    if (!match) {
      reply.code(416);
      reply.header("Content-Range", `bytes */${size}`);
      reply.send();
      return;
    }
    let start = match[1] ? Number(match[1]) : 0;
    let end = match[2] ? Number(match[2]) : size - 1;
    if (Number.isNaN(start) || Number.isNaN(end) || start > end || end >= size) {
      reply.code(416);
      reply.header("Content-Range", `bytes */${size}`);
      reply.send();
      return;
    }
    const chunkSize = end - start + 1;
    reply.code(206);
    reply.header("Content-Range", `bytes ${start}-${end}/${size}`);
    reply.header("Content-Length", chunkSize);
    reply.send(fs.createReadStream(absPath, { start, end }));
    return;
  }

  reply.header("Content-Length", size);
  reply.send(fs.createReadStream(absPath));
}

const downloadRoutes: FastifyPluginAsync = async (app) => {
  app.post("/downloads", { preHandler: authDevice }, async (request, reply) => {
    const parsed = createDownloadSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new AppError(codes.BAD_REQUEST, "Invalid body", 400);
    }
    const ctx = request.deviceCtx!;
    const device = await app.prisma.device.findUnique({ where: { id: ctx.id } });
    const dailyLimit = device?.dailyLimit ?? ctx.dailyLimit;

    const result = await createDownload({
      prisma: app.prisma,
      redis: app.redis,
      queue: app.downloadQueue,
      deviceId: ctx.id,
      dailyLimit,
      body: parsed.data,
    });
    reply.send(result);
  });

  app.get("/downloads", { preHandler: authDevice }, async (request, reply) => {
    const parsed = listDownloadsQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new AppError(codes.BAD_REQUEST, "Invalid query", 400);
    }
    const ctx = request.deviceCtx!;
    const result = await listDownloadsForDevice(app.prisma, ctx.id, parsed.data);
    reply.send(result);
  });

  app.get("/downloads/:jobId", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const jobId = (request.params as { jobId: string }).jobId;
    const result = await getDownloadForDevice(app.prisma, ctx.id, jobId);
    reply.send(result);
  });

  app.post("/downloads/:jobId/retry", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const jobId = (request.params as { jobId: string }).jobId;
    const result = await retryDownload({
      prisma: app.prisma,
      queue: app.downloadQueue,
      deviceId: ctx.id,
      jobId,
    });
    reply.send(result);
  });

  app.delete("/downloads/:jobId", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const jobId = (request.params as { jobId: string }).jobId;
    await deleteDownload({ prisma: app.prisma, deviceId: ctx.id, jobId });
    reply.code(204).send();
  });

  app.get("/downloads/:jobId/file", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const jobId = (request.params as { jobId: string }).jobId;

    const job = await app.prisma.downloadJob.findFirst({
      where: { id: jobId, deviceId: ctx.id },
      include: { files: true },
    });
    if (!job) {
      throw new AppError(codes.JOB_NOT_FOUND, "Job not found", 404);
    }
    if (job.status !== "done") {
      throw new AppError(codes.BAD_REQUEST, "Download not completed", 400);
    }

    const primary =
      job.files.find((f: FileAsset) => f.type === "video") ?? job.files.find((f: FileAsset) => f.type === "audio");
    if (!primary) {
      throw new AppError(codes.FILE_NOT_FOUND, "No media file for job", 404);
    }

    const absPath = resolveAbsoluteFromStorageKey(primary.storageKey);
    await streamAssetFile(
      request,
      reply,
      absPath,
      primary.filename,
      primary.mimeType ?? "application/octet-stream"
    );
  });
};

export default downloadRoutes;
