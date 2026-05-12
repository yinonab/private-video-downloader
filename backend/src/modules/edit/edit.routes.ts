import fs from "node:fs";
import fsp from "node:fs/promises";
import type { FastifyReply, FastifyRequest } from "fastify";
import { type FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { authDevice } from "../../middleware/authDevice";
import { resolveAbsoluteFromStorageKey } from "../../services/storage";
import { AppError, codes } from "../../types/errors";
import {
  createEditJob,
  getEditJobForDevice,
  retryEditJob,
} from "./edit.service";

const editIdParamsSchema = z.object({
  id: z.string().uuid(),
});

async function streamEditOutputFile(
  request: FastifyRequest,
  reply: FastifyReply,
  absPath: string,
  stat: fs.Stats,
  filename: string,
  mimeType: string
): Promise<void> {
  const size = stat.size;
  if (!stat.isFile() || size <= 0) {
    throw new AppError(codes.FILE_NOT_FOUND, "Edited file missing or empty on disk", 404);
  }

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

const editRoutes: FastifyPluginAsync = async (app) => {
  app.post("/edits", { preHandler: authDevice }, async (request, reply) => {
    const ctx = request.deviceCtx!;
    const result = await createEditJob({
      prisma: app.prisma,
      queue: app.editQueue,
      deviceId: ctx.id,
      body: request.body,
    });
    reply.send(result);
  });

  app.get("/edits/:id", { preHandler: authDevice }, async (request, reply) => {
    const parsed = editIdParamsSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new AppError(codes.BAD_REQUEST, "Invalid edit id", 400);
    }
    const ctx = request.deviceCtx!;
    const result = await getEditJobForDevice({
      prisma: app.prisma,
      deviceId: ctx.id,
      editJobId: parsed.data.id,
    });
    reply.send(result);
  });

  app.post("/edits/:id/retry", { preHandler: authDevice }, async (request, reply) => {
    const parsed = editIdParamsSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new AppError(codes.BAD_REQUEST, "Invalid edit id", 400);
    }
    const ctx = request.deviceCtx!;
    const result = await retryEditJob({
      prisma: app.prisma,
      queue: app.editQueue,
      deviceId: ctx.id,
      editJobId: parsed.data.id,
    });
    reply.send(result);
  });

  app.get("/edits/:id/file", { preHandler: authDevice }, async (request, reply) => {
    const parsed = editIdParamsSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new AppError(codes.BAD_REQUEST, "Invalid edit id", 400);
    }
    const ctx = request.deviceCtx!;
    const editJobId = parsed.data.id;

    const row = await app.prisma.editJob.findFirst({
      where: { id: editJobId, deviceId: ctx.id },
    });
    if (!row) {
      throw new AppError(codes.EDIT_JOB_NOT_FOUND, "Edit job not found", 404);
    }
    if (row.status !== "done" || row.outputStorageKey == null || row.outputStorageKey === "") {
      throw new AppError(codes.BAD_REQUEST, "Edited output not ready", 400);
    }

    let absPath: string;
    try {
      absPath = resolveAbsoluteFromStorageKey(row.outputStorageKey);
    } catch {
      throw new AppError(codes.FILE_NOT_FOUND, "Invalid output storage key", 404);
    }

    let st: fs.Stats;
    try {
      st = await fsp.stat(absPath);
    } catch {
      throw new AppError(codes.FILE_NOT_FOUND, "Edited file missing on disk", 404);
    }

    await streamEditOutputFile(
      request,
      reply,
      absPath,
      st,
      row.outputFilename ?? `${editJobId}.mp4`,
      row.outputMimeType ?? "video/mp4"
    );
  });
};

export default editRoutes;
