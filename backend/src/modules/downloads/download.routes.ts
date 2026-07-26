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
import { logDownloadPerf, startPerfTimer } from "../../services/downloadPerf";

type ReadableMediaPick = {
  asset: FileAsset;
  absPath: string;
  stat: fs.Stats;
};

/** Resolve DB file rows to a real non-empty file on disk (prefers video, then largest size). */
async function pickReadableMediaFile(
  request: FastifyRequest,
  jobId: string,
  deviceId: string,
  files: FileAsset[]
): Promise<ReadableMediaPick | null> {
  const mediaAssets = files.filter((f) => f.type === "video" || f.type === "audio");
  const picks: ReadableMediaPick[] = [];

  for (const asset of mediaAssets) {
    let absPath: string;
    try {
      absPath = resolveAbsoluteFromStorageKey(asset.storageKey);
    } catch (err) {
      request.log.warn(
        { jobId, deviceId, dbStorageKey: asset.storageKey, err },
        "download file: invalid storage key"
      );
      continue;
    }

    let st: fs.Stats;
    try {
      st = await fsp.stat(absPath);
    } catch {
      request.log.warn(
        {
          jobId,
          deviceId,
          dbStorageKey: asset.storageKey,
          resolvedAbsolutePath: absPath,
          exists: false,
        },
        "download file: stat failed (missing path)"
      );
      continue;
    }

    const exists = true;
    request.log.info(
      {
        jobId,
        deviceId,
        dbStorageKey: asset.storageKey,
        resolvedAbsolutePath: absPath,
        exists,
        statSize: st.size,
        isFile: st.isFile(),
        isDirectory: st.isDirectory(),
        filename: asset.filename,
        mimeType: asset.mimeType,
        assetType: asset.type,
        dbSizeBytes: asset.sizeBytes != null ? asset.sizeBytes.toString() : null,
      },
      "download file: resolved path stat"
    );

    if (!st.isFile()) {
      request.log.warn(
        { jobId, deviceId, resolvedAbsolutePath: absPath, statSize: st.size },
        "download file: skip — not a regular file"
      );
      continue;
    }

    if (st.size <= 0) {
      request.log.warn(
        { jobId, deviceId, resolvedAbsolutePath: absPath, statSize: st.size },
        "download file: skip — empty or zero-length file"
      );
      continue;
    }

    picks.push({ asset, absPath, stat: st });
  }

  if (!picks.length) return null;

  picks.sort((a, b) => {
    const vp = a.asset.type === "video" ? 1 : 0;
    const vq = b.asset.type === "video" ? 1 : 0;
    if (vp !== vq) return vq - vp;
    return Number(b.stat.size - a.stat.size);
  });

  const chosen = picks[0]!;
  request.log.info(
    {
      jobId,
      deviceId,
      chosenStorageKey: chosen.asset.storageKey,
      chosenAbsolutePath: chosen.absPath,
      chosenStatSize: chosen.stat.size,
      chosenFilename: chosen.asset.filename,
    },
    "download file: chosen asset for streaming"
  );

  return chosen;
}

async function streamAssetFile(
  request: FastifyRequest,
  reply: FastifyReply,
  absPath: string,
  stat: fs.Stats,
  filename: string,
  mimeType: string
): Promise<void> {
  const size = stat.size;
  if (!stat.isFile() || size <= 0) {
    throw new AppError(codes.FILE_NOT_FOUND, "Media file missing or empty on disk", 404);
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

const downloadRoutes: FastifyPluginAsync = async (app) => {
  app.post("/downloads", { preHandler: authDevice }, async (request, reply) => {
    const parsed = createDownloadSchema.safeParse(request.body);
    if (!parsed.success) {
      request.log.warn(
        {
          downloadValidate: true,
          accepted: false,
          reason: "schema",
          issues: parsed.error.flatten(),
          formatReceived: (request.body as { format?: unknown })?.format,
          qualityReceived: (request.body as { quality?: unknown })?.quality,
        },
        "POST /downloads validation failed"
      );
      throw new AppError(codes.BAD_REQUEST, "Invalid body", 400);
    }
    request.log.info(
      {
        downloadValidate: true,
        acceptedShape: true,
        formatReceived: parsed.data.format,
        qualityReceived: parsed.data.quality,
        forceNew: parsed.data.forceNew === true,
      },
      "POST /downloads body shape ok"
    );
    const ctx = request.deviceCtx!;
    const device = await app.prisma.device.findUnique({ where: { id: ctx.id } });
    const dailyLimit = device?.dailyLimit ?? ctx.dailyLimit;

    const createTimer = startPerfTimer();
    const result = await createDownload({
      prisma: app.prisma,
      redis: app.redis,
      queue: app.downloadQueue,
      deviceId: ctx.id,
      dailyLimit,
      body: parsed.data,
    });
    logDownloadPerf({
      stage: "job_create",
      durationMs: createTimer.elapsedMs(),
      jobId: result.jobId,
      quality: String(parsed.data.format ?? parsed.data.quality ?? "unknown"),
      cached: result.cached === true,
      result: result.cached === true ? "cache_hit" : "created",
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

    const picked = await pickReadableMediaFile(request, jobId, ctx.id, job.files);
    if (!picked) {
      throw new AppError(
        codes.FILE_NOT_FOUND,
        "Media file missing or empty on disk",
        404,
        "No readable video/audio file with size > 0 for this job"
      );
    }

    await streamAssetFile(
      request,
      reply,
      picked.absPath,
      picked.stat,
      picked.asset.filename,
      picked.asset.mimeType ?? "application/octet-stream"
    );
  });
};

export default downloadRoutes;
