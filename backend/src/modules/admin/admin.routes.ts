import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { authAdmin } from "../../middleware/authAdmin";
import { config } from "../../config";
import { getYtDlpVersion, type DownloadFormatKind } from "../../services/ytdlp";
import { DOWNLOAD_ALLOWED_FORMATS } from "../../modules/downloads/download.service";
import { logger } from "../../services/logger";
import { deleteJobFilesFromDisk } from "../../services/storage";
import type { Device, InviteCode } from "@prisma/client";

const inviteBodySchema = z.object({
  maxUses: z.coerce.number().min(1).max(10_000).optional(),
  code: z.string().min(4).max(64).optional(),
});

async function dirTotalBytes(dir: string): Promise<number> {
  let total = 0;
  let entries;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch {
    return 0;
  }
  for (const ent of entries) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      total += await dirTotalBytes(p);
    } else if (ent.isFile()) {
      const st = await fs.stat(p).catch(() => null);
      total += st?.size ?? 0;
    }
  }
  return total;
}

function runCmd(argv: string[]): Promise<{ code: number | null; stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(argv[0]!, argv.slice(1), { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d.toString()));
    child.stderr.on("data", (d) => (stderr += d.toString()));
    child.on("error", reject);
    child.on("close", (code) => resolve({ code, stdout, stderr }));
  });
}

const adminRoutes: FastifyPluginAsync = async (app) => {
  app.addHook("preHandler", authAdmin);

  app.get("/health", async () => {
    let postgresOk = false;
    try {
      await app.prisma.$queryRaw`SELECT 1`;
      postgresOk = true;
    } catch {
      postgresOk = false;
    }
    let redisOk = false;
    try {
      const pong = await app.redis.ping();
      redisOk = pong === "PONG";
    } catch {
      redisOk = false;
    }
    const ytDlpVersion = await getYtDlpVersion();

    return {
      postgres: postgresOk ? "ok" : "down",
      redis: redisOk ? "ok" : "down",
      ytDlpVersion,
      storageDir: config.storageDir,
    };
  });

  app.get("/devices", async () => {
    const devices = await app.prisma.device.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
    });
    return {
      items: devices.map((d: Device) => ({
        id: d.id,
        name: d.name,
        platform: d.platform,
        status: d.status,
        dailyLimit: d.dailyLimit,
        createdAt: d.createdAt.toISOString(),
        lastSeenAt: d.lastSeenAt.toISOString(),
      })),
    };
  });

  app.post("/devices/:deviceId/block", async (request) => {
    const deviceId = (request.params as { deviceId: string }).deviceId;
    await app.prisma.device.update({
      where: { id: deviceId },
      data: { status: "blocked" },
    });
    logger.warn({ deviceId }, "device blocked via admin");
    return { ok: true };
  });

  app.post("/devices/:deviceId/unblock", async (request) => {
    const deviceId = (request.params as { deviceId: string }).deviceId;
    await app.prisma.device.update({
      where: { id: deviceId },
      data: { status: "active" },
    });
    logger.info({ deviceId }, "device unblocked via admin");
    return { ok: true };
  });

  app.get("/invite-codes", async () => {
    const codesList = await app.prisma.inviteCode.findMany({ orderBy: { createdAt: "desc" }, take: 200 });
    return {
      items: codesList.map((c: InviteCode) => ({
        id: c.id,
        code: c.code,
        maxUses: c.maxUses,
        usedCount: c.usedCount,
        active: c.active,
        createdAt: c.createdAt.toISOString(),
        expiresAt: c.expiresAt?.toISOString() ?? null,
      })),
    };
  });

  app.post("/invite-codes", async (request, reply) => {
    const parsed = inviteBodySchema.safeParse(request.body ?? {});
    if (!parsed.success) {
      reply.status(400).send({ error: { code: "BAD_REQUEST", message: "Invalid body" } });
      return;
    }
    const maxUses = parsed.data.maxUses ?? 1;
    const code =
      parsed.data.code ??
      `INV-${crypto.randomBytes(4).toString("hex").toUpperCase()}-${crypto.randomBytes(2).toString("hex").toUpperCase()}`;
    const created = await app.prisma.inviteCode.create({
      data: { code, maxUses },
    });
    reply.send({
      id: created.id,
      code: created.code,
      maxUses: created.maxUses,
      usedCount: created.usedCount,
    });
  });

  app.get("/jobs", async (request) => {
    const q = request.query as { limit?: string };
    const limit = Math.min(Number(q.limit ?? "50"), 200);
    const jobs = await app.prisma.downloadJob.findMany({
      orderBy: { createdAt: "desc" },
      take: limit,
      include: { link: true, device: { select: { id: true, platform: true } } },
    });
    type JobAdminRow = (typeof jobs)[number];
    return {
      items: jobs.map((j: JobAdminRow) => ({
        id: j.id,
        deviceId: j.deviceId,
        status: j.status,
        progress: j.progress,
        format: j.format,
        quality: j.quality,
        title: j.link.title,
        error: j.error,
        createdAt: j.createdAt.toISOString(),
      })),
    };
  });

  app.post("/jobs/:jobId/retry", async (request, reply) => {
    const jobId = (request.params as { jobId: string }).jobId;
    const job = await app.prisma.downloadJob.findUnique({
      where: { id: jobId },
      include: { link: true },
    });
    if (!job) {
      reply.status(404).send({ error: { code: "JOB_NOT_FOUND", message: "Not found" } });
      return;
    }
    if (!["failed", "canceled"].includes(job.status)) {
      reply.status(400).send({ error: { code: "BAD_REQUEST", message: "Job cannot be retried" } });
      return;
    }
    const fmt = job.format ?? "best";
    const allowed = new Set<string>(DOWNLOAD_ALLOWED_FORMATS);
    const kind = (allowed.has(fmt) ? fmt : "best") as DownloadFormatKind;

    await app.prisma.downloadJob.update({
      where: { id: job.id },
      data: {
        status: "queued",
        progress: 0,
        error: null,
        speedText: null,
        etaText: null,
      },
    });

    await app.downloadQueue.add(
      job.id,
      {
        jobId: job.id,
        deviceId: job.deviceId,
        url: job.link.url,
        format: kind,
      },
      { jobId: job.id, attempts: 1, removeOnComplete: true, removeOnFail: false }
    );

    reply.send({ jobId: job.id, status: "queued" });
  });

  app.delete("/jobs/:jobId", async (request, reply) => {
    const jobId = (request.params as { jobId: string }).jobId;
    const job = await app.prisma.downloadJob.findUnique({ where: { id: jobId } });
    if (!job) {
      reply.status(404).send({ error: { code: "JOB_NOT_FOUND", message: "Not found" } });
      return;
    }
    await deleteJobFilesFromDisk(job.deviceId, jobId);
    await app.prisma.downloadJob.delete({ where: { id: jobId } });
    reply.code(204).send();
  });

  app.get("/storage", async () => {
    const root = path.join(config.storageDir, "devices");
    let entries: string[] = [];
    try {
      entries = await fs.readdir(root);
    } catch {
      return { devices: [] as { deviceId: string; bytes: number }[] };
    }

    const devices: { deviceId: string; bytes: number }[] = [];
    for (const id of entries) {
      const bytes = await dirTotalBytes(path.join(root, id));
      devices.push({ deviceId: id, bytes });
    }
    return { devices };
  });

  app.post("/update-ytdlp", async () => {
    const { code, stderr } = await runCmd([
      "python3",
      "-m",
      "pip",
      "install",
      "--break-system-packages",
      "-U",
      "yt-dlp[default,curl-cffi]",
    ]);
    const version = await getYtDlpVersion();
    return { exitCode: code, version, stderrTail: stderr.slice(-2000) };
  });

  app.post("/cleanup", async () => {
    const tmp = path.join(config.storageDir, "temp");
    await fs.mkdir(tmp, { recursive: true });
    let removed = 0;
    try {
      const files = await fs.readdir(tmp);
      for (const f of files) {
        await fs.unlink(path.join(tmp, f)).catch(() => undefined);
        removed++;
      }
    } catch {
      removed = 0;
    }
    return { removed };
  });
};

export default adminRoutes;
