import { spawn } from "node:child_process";
import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import readline from "node:readline";
import type { FastifyInstance } from "fastify";
import { config } from "../../config";
import {
  looksLikeNetscapeCookiesFileContent,
  probeYtDlpCookiesTempCopy,
  YTDLP_JS_RUNTIME_ARGS,
} from "../../services/ytdlp";

const CMD_TIMEOUT_MS = 12_000;
const DEEP_YTDLP_TIMEOUT_MS = 28_000;
const MAX_COOKIE_SCAN_BYTES = 512 * 1024;
const MAX_FILE_COUNT_WALK = 100_000;

type OverallStatus = "healthy" | "warning" | "critical";
type CheckStatus = "healthy" | "warning" | "critical" | "skipped";

export type ToolProbe = {
  ok: boolean;
  value: string | null;
  error: string | null;
};

type MajorCheck = {
  ok: boolean;
  status: CheckStatus;
  summary: string;
  details: Record<string, unknown>;
};

function formatBytes(n: number): string {
  if (!Number.isFinite(n) || n < 0) return "?";
  const units = ["B", "K", "M", "G", "T"];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  const digits = i === 0 ? 0 : i === 1 ? 1 : 2;
  return `${v.toFixed(digits)}${units[i]}`;
}

/** Hide host-specific paths; allow standard Docker mount paths. */
export function safePathForDiagnostics(resolved: string): string {
  const norm = path.normalize(resolved);
  if (
    norm.startsWith("/app/storage") ||
    norm.startsWith("/app/secrets/") ||
    norm === "/app/secrets/cookies/global.txt"
  ) {
    return norm;
  }
  const base = path.basename(norm);
  const parent = path.basename(path.dirname(norm));
  return parent && parent !== "." ? `…/${parent}/${base}` : base;
}

function jsRuntimeArgsConfigured(): boolean {
  const expected = ["--no-js-runtimes", "--js-runtimes", "node"];
  return (
    expected.length === YTDLP_JS_RUNTIME_ARGS.length &&
    expected.every((x, i) => x === YTDLP_JS_RUNTIME_ARGS[i])
  );
}

async function runCmd(argv: string[], timeoutMs: number): Promise<{
  code: number | null;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  spawnError: string | null;
}> {
  return new Promise((resolve) => {
    let timedOut = false;
    const child = spawn(argv[0]!, argv.slice(1), {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    });
    let stdout = "";
    let stderr = "";
    const t = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    child.stdout?.on("data", (d: Buffer) => (stdout += d.toString()));
    child.stderr?.on("data", (d: Buffer) => (stderr += d.toString()));
    child.on("error", (err) => {
      clearTimeout(t);
      resolve({
        code: null,
        stdout,
        stderr,
        timedOut: false,
        spawnError: err instanceof Error ? err.message : String(err),
      });
    });
    child.on("close", (code) => {
      clearTimeout(t);
      resolve({ code, stdout, stderr, timedOut, spawnError: null });
    });
  });
}

function toolProbeFromCmd(
  result: Awaited<ReturnType<typeof runCmd>>,
  transform: (stdout: string) => string | null
): ToolProbe {
  if (result.spawnError) {
    return { ok: false, value: null, error: result.spawnError };
  }
  if (result.timedOut) {
    return { ok: false, value: null, error: "timed out" };
  }
  if (result.code !== 0) {
    const tail = (result.stderr || result.stdout).trim().slice(-400);
    return { ok: false, value: null, error: tail || `exit ${result.code}` };
  }
  try {
    const v = transform(result.stdout);
    return { ok: true, value: v, error: null };
  } catch (e) {
    return { ok: false, value: null, error: e instanceof Error ? e.message : String(e) };
  }
}

async function countFilesRecursive(root: string): Promise<number> {
  let count = 0;
  async function walk(dir: string): Promise<void> {
    let entries;
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const ent of entries) {
      if (count >= MAX_FILE_COUNT_WALK) return;
      const p = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        await walk(p);
      } else if (ent.isFile()) {
        count++;
      }
    }
  }
  await walk(root);
  return count;
}

async function storageWritableProbe(storageDir: string): Promise<{ ok: boolean; error: string | null }> {
  const fn = `.linkclip-diag-${process.pid}-${Date.now()}`;
  const target = path.join(storageDir, fn);
  try {
    await fs.mkdir(storageDir, { recursive: true });
    await fs.writeFile(target, "ok", "utf8");
    await fs.unlink(target);
    return { ok: true, error: null };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  }
}

async function duStorageBytes(storageDir: string): Promise<number | null> {
  const r = await runCmd(["du", "-sb", storageDir], CMD_TIMEOUT_MS);
  if (r.code !== 0 || r.timedOut || r.spawnError) return null;
  const m = r.stdout.trim().match(/^(\d+)/);
  return m ? Number(m[1]) : null;
}

async function dfStorage(storageDir: string): Promise<{
  totalKb: number | null;
  usedKb: number | null;
  availKb: number | null;
  usePercent: number | null;
  rawLine: string | null;
  error: string | null;
}> {
  const r = await runCmd(["df", "-Pk", storageDir], CMD_TIMEOUT_MS);
  if (r.spawnError || r.timedOut || r.code !== 0) {
    return {
      totalKb: null,
      usedKb: null,
      availKb: null,
      usePercent: null,
      rawLine: null,
      error: r.spawnError ?? (r.timedOut ? "timed out" : "df failed"),
    };
  }
  const lines = r.stdout.trim().split("\n").filter(Boolean);
  const dataLine = lines.length >= 2 ? lines[lines.length - 1]! : null;
  if (!dataLine) {
    return {
      totalKb: null,
      usedKb: null,
      availKb: null,
      usePercent: null,
      rawLine: null,
      error: "unexpected df output",
    };
  }
  const parts = dataLine.split(/\s+/);
  // Filesystem 1024-blocks Used Available Capacity Mounted-on
  const totalKb = Number(parts[1]);
  const usedKb = Number(parts[2]);
  const availKb = Number(parts[3]);
  const cap = parts[4] ?? "";
  const pctMatch = cap.match(/(\d+)%/);
  const usePercent = pctMatch ? Number(pctMatch[1]) : Number.NaN;
  return {
    totalKb: Number.isFinite(totalKb) ? totalKb : null,
    usedKb: Number.isFinite(usedKb) ? usedKb : null,
    availKb: Number.isFinite(availKb) ? availKb : null,
    usePercent: Number.isFinite(usePercent) ? usePercent : null,
    rawLine: dataLine,
    error: null,
  };
}

type CookieDomains = {
  hasInstagramCookies: boolean;
  hasFacebookCookies: boolean;
  hasTikTokCookies: boolean;
  hasYouTubeOrGoogleCookies: boolean;
  hasThreadsCookies: boolean;
};

function scanCookieDomainsFromText(text: string): CookieDomains {
  const out: CookieDomains = {
    hasInstagramCookies: false,
    hasFacebookCookies: false,
    hasTikTokCookies: false,
    hasYouTubeOrGoogleCookies: false,
    hasThreadsCookies: false,
  };
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const domain = line.split("\t")[0]?.trim().toLowerCase();
    if (!domain) continue;
    if (domain.includes("instagram")) out.hasInstagramCookies = true;
    if (domain.includes("facebook")) out.hasFacebookCookies = true;
    if (domain.includes("tiktok")) out.hasTikTokCookies = true;
    if (
      domain.includes("youtube") ||
      domain.includes("googlevideo") ||
      domain === "google.com" ||
      domain.endsWith(".google.com") ||
      domain.endsWith(".youtube.com")
    ) {
      out.hasYouTubeOrGoogleCookies = true;
    }
    if (domain.includes("threads.com") || domain.includes("threads.net")) out.hasThreadsCookies = true;
  }
  return out;
}

async function countLinesInFile(absPath: string): Promise<number> {
  const stream = createReadStream(absPath, { encoding: "utf8" });
  const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
  let n = 0;
  for await (const _ of rl) {
    n++;
  }
  return n;
}

async function loadCookiesForDiagnostics(absPath: string, byteSize: number): Promise<{
  textForValidateAndDomains: string;
  lineCount: number;
  lineCountApproximate: boolean;
}> {
  if (byteSize <= MAX_COOKIE_SCAN_BYTES) {
    const full = await fs.readFile(absPath, "utf8");
    const lineCount = full.split(/\r?\n/).length;
    return { textForValidateAndDomains: full, lineCount, lineCountApproximate: false };
  }
  /** Large jar: validate/domains from head only; line count streams entire file (no subprocess path leakage). */
  const fh = await fs.open(absPath, "r");
  const buf = Buffer.allocUnsafe(Math.min(MAX_COOKIE_SCAN_BYTES, byteSize));
  try {
    await fh.read(buf, 0, buf.length, 0);
  } finally {
    await fh.close();
  }
  const head = buf.toString("utf8");
  const lineCount = await countLinesInFile(absPath);
  return {
    textForValidateAndDomains: head,
    lineCount,
    lineCountApproximate: false,
  };
}

export type DiagnosticsResult = {
  ok: boolean;
  status: OverallStatus;
  shortcuts: {
    downloadsReady: boolean;
    storageOk: boolean;
    cookiesOk: boolean;
    youtubeReady: boolean;
    ytDlpOk: boolean;
    ffmpegOk: boolean;
    nodeJsRuntimeOk: boolean;
    cleanupConfigured: boolean;
    diskUsagePercent: number | null;
    storageFileCount: number;
    storageUsedHuman: string;
    mainWarnings: string[];
  };
  checks: Record<string, MajorCheck | Record<string, unknown>>;
};

export async function runDiagnostics(
  app: FastifyInstance,
  opts: { deep: boolean }
): Promise<DiagnosticsResult> {
  const mainWarnings: string[] = [];
  const pushWarn = (w: string) => {
    if (!mainWarnings.includes(w)) mainWarnings.push(w);
  };

  let pkgVersion: string | null = null;
  try {
    const raw = await fs.readFile(path.join(process.cwd(), "package.json"), "utf8");
    const j = JSON.parse(raw) as { version?: string };
    pkgVersion = typeof j.version === "string" ? j.version : null;
  } catch {
    pkgVersion = null;
  }

  const [
    ytDlpProbe,
    ffmpegProbe,
    ffprobeProbe,
    nodeVerProbe,
    nodePathProbe,
    ytEjsProbe,
    curlCffiProbe,
  ] = await Promise.all([
    runCmd(["yt-dlp", "--version"], CMD_TIMEOUT_MS).then((r) =>
      toolProbeFromCmd(r, (o) => o.trim().split("\n")[0] ?? null)
    ),
    runCmd(["ffmpeg", "-version"], CMD_TIMEOUT_MS).then((r) =>
      toolProbeFromCmd(r, (o) => o.trim().split("\n")[0] ?? null)
    ),
    runCmd(["ffprobe", "-version"], CMD_TIMEOUT_MS).then((r) =>
      toolProbeFromCmd(r, (o) => o.trim().split("\n")[0] ?? null)
    ),
    runCmd(["node", "--version"], CMD_TIMEOUT_MS).then((r) =>
      toolProbeFromCmd(r, (o) => o.trim().split("\n")[0] ?? null)
    ),
    runCmd(["sh", "-c", "command -v node"], CMD_TIMEOUT_MS).then((r) =>
      toolProbeFromCmd(r, (o) => {
        const p = o.trim().split("\n")[0];
        return p || null;
      })
    ),
    runCmd(
      ["python3", "-c", "from yt_dlp.dependencies import yt_dlp_ejs; print(bool(yt_dlp_ejs))"],
      CMD_TIMEOUT_MS
    ).then((r) =>
      toolProbeFromCmd(r, (o) => {
        const t = o.trim().toLowerCase();
        return t.includes("true") ? "true" : t.includes("false") ? "false" : null;
      })
    ),
    runCmd(["python3", "-c", "import importlib.util as u; print(bool(u.find_spec('curl_cffi')))"], CMD_TIMEOUT_MS).then(
      (r) =>
        toolProbeFromCmd(r, (o) => {
          const t = o.trim().toLowerCase();
          return t.includes("true") ? "true" : "false";
        })
    ),
  ]);

  const ytDlpEjsInstalled = ytEjsProbe.ok && ytEjsProbe.value === "true";
  const curlCffiInstalled = curlCffiProbe.ok && curlCffiProbe.value === "true";
  const jsArgsOk = jsRuntimeArgsConfigured();
  const nodeAvailable = nodeVerProbe.ok && !!nodeVerProbe.value;

  if (!ytDlpProbe.ok) pushWarn("yt-dlp is missing or not working");
  if (!ffmpegProbe.ok) pushWarn("ffmpeg is missing or not working");
  if (!ffprobeProbe.ok) pushWarn("ffprobe is missing or not working");
  if (!nodeAvailable) pushWarn("Node.js runtime is missing");
  if (!ytDlpEjsInstalled) pushWarn("yt-dlp-ejs is not installed");
  if (!jsArgsOk) pushWarn("YTDLP_JS_RUNTIME_ARGS are not configured as expected");

  const storageDir = config.storageDir;
  const storageExists = await fs
    .stat(storageDir)
    .then((s) => s.isDirectory())
    .catch(() => false);
  const writable = storageExists ? await storageWritableProbe(storageDir) : { ok: false, error: "missing" };
  if (!storageExists) pushWarn("Storage directory does not exist");
  else if (!writable.ok) pushWarn("Storage is not writable");

  let storageFileCount = 0;
  let storageBytes: number | null = null;
  if (storageExists) {
    storageFileCount = await countFilesRecursive(storageDir);
    storageBytes = await duStorageBytes(storageDir);
  }

  const df = storageExists ? await dfStorage(storageDir) : null;
  if (df?.usePercent != null && df.usePercent >= 80) {
    pushWarn(df.usePercent >= 90 ? "Disk usage is at or above 90%" : "Disk usage is at or above 80%");
  }

  const diskUsagePercent = df?.usePercent ?? null;

  const cookiesConfigured = Boolean(config.cookiesFile?.trim());
  let cookiesOk = false;
  let cookieDetails: MajorCheck["details"] = {
    cookiesConfigured,
    cookiesFilePathSafe: null as string | null,
    fileExists: false,
    fileSizeBytes: null as number | null,
    lineCount: null as number | null,
    lineCountApproximate: false,
    readable: false,
    validNetscapeLooking: false,
    domains: null as CookieDomains | null,
    mtimeIso: null as string | null,
  };

  if (cookiesConfigured && config.cookiesFile) {
    const abs = path.resolve(config.cookiesFile);
    cookieDetails.cookiesFilePathSafe = safePathForDiagnostics(abs);
    let st;
    try {
      st = await fs.stat(abs);
    } catch {
      st = null;
    }
    if (!st || !st.isFile()) {
      pushWarn("COOKIES_FILE is configured but file is missing");
      cookieDetails.fileExists = false;
    } else {
      cookieDetails.fileExists = true;
      cookieDetails.fileSizeBytes = st.size;
      cookieDetails.mtimeIso = st.mtime.toISOString();
      if (st.size === 0) {
        pushWarn("Cookies file is empty");
      }
      try {
        const loaded = await loadCookiesForDiagnostics(abs, st.size);
        cookieDetails.lineCount = loaded.lineCount;
        cookieDetails.lineCountApproximate = loaded.lineCountApproximate;
        cookieDetails.readable = true;
        const validNetscape = looksLikeNetscapeCookiesFileContent(loaded.textForValidateAndDomains);
        cookieDetails.validNetscapeLooking = validNetscape;
        cookieDetails.domains = scanCookieDomainsFromText(loaded.textForValidateAndDomains);
        cookiesOk = st.size > 0 && validNetscape && loaded.lineCount > 0;
        if (!validNetscape && st.size > 0) pushWarn("Cookies file does not look like valid Netscape format");
        if (cookiesOk) {
          const tempProbe = await probeYtDlpCookiesTempCopy();
          cookieDetails.tempCopyOk = tempProbe.ok;
          cookieDetails.tempCopyWritable = tempProbe.tempWritable;
          cookieDetails.tempCopyBasename = tempProbe.tempBasename;
          cookieDetails.tempCopyBytes = tempProbe.bytesCopied;
          if (!tempProbe.ok) {
            cookiesOk = false;
            pushWarn(tempProbe.error ?? "yt-dlp cookies temp copy probe failed");
          }
        }
      } catch (e) {
        cookieDetails.readable = false;
        cookieDetails.readError = e instanceof Error ? e.message : String(e);
        pushWarn("Cookies file could not be read");
      }
    }
  } else {
    pushWarn("COOKIES_FILE is missing");
  }

  const youtubeOrGoogleCookiesDetected =
    !!cookieDetails.domains && (cookieDetails.domains as CookieDomains).hasYouTubeOrGoogleCookies;

  const youtubeReadinessDetails: Record<string, unknown> = {
    jsRuntimeArgsConfigured: jsArgsOk,
    jsRuntimeArgs: [...YTDLP_JS_RUNTIME_ARGS],
    nodeAvailable,
    nodeVersion: nodeVerProbe.value,
    nodePath: nodePathProbe.value,
    ytDlpEjsInstalled,
    cookiesConfigured,
    youtubeOrGoogleCookiesDetected,
    ready:
      ytDlpProbe.ok &&
      nodeAvailable &&
      ytDlpEjsInstalled &&
      jsArgsOk,
  };

  const youtubeReady = youtubeReadinessDetails.ready === true;

  if (!youtubeReady) pushWarn("YouTube JS runtime / yt-dlp-ejs readiness check failed");

  /** Deep YouTube probe */
  let deepYoutube: MajorCheck | undefined;
  if (opts.deep) {
    const testUrl = process.env.ADMIN_DIAGNOSTICS_YOUTUBE_TEST_URL?.trim();
    if (!testUrl) {
      deepYoutube = {
        ok: false,
        status: "skipped",
        summary: "Skipped deep YouTube test (ADMIN_DIAGNOSTICS_YOUTUBE_TEST_URL unset)",
        details: {},
      };
    } else {
      const args = [
        "yt-dlp",
        ...YTDLP_JS_RUNTIME_ARGS,
        "--no-config",
        "--skip-download",
        "--no-warnings",
        "--print",
        "%(id)s",
        testUrl,
      ];
      const r = await runCmd(args, DEEP_YTDLP_TIMEOUT_MS);
      const ok = !r.spawnError && !r.timedOut && r.code === 0 && r.stdout.trim().length > 0;
      if (!ok) pushWarn("Deep YouTube diagnostics command failed");
      deepYoutube = {
        ok,
        status: ok ? "healthy" : r.timedOut ? "warning" : "warning",
        summary: ok ? "Deep YouTube probe succeeded" : "Deep YouTube probe failed",
        details: {
          timedOut: r.timedOut,
          exitCode: r.code,
          stderrTail: r.stderr.trim().slice(-600),
          stdoutSnippet: r.stdout.trim().slice(0, 120),
        },
      };
    }
    youtubeReadinessDetails.deepProbe = deepYoutube;
  }

  /** DB */
  let dbOk = false;
  let dbError: string | null = null;
  try {
    await app.prisma.$queryRaw`SELECT 1`;
    dbOk = true;
  } catch (e) {
    dbError = e instanceof Error ? e.message : String(e);
    pushWarn("Database connectivity failed");
  }

  /** Redis */
  let redisOk = false;
  let redisError: string | null = null;
  try {
    redisOk = (await app.redis.ping()) === "PONG";
  } catch (e) {
    redisError = e instanceof Error ? e.message : String(e);
    pushWarn("Redis connectivity failed");
  }

  /** Queues */
  let queueDetails: Record<string, unknown> = { skippedReason: null as string | null };
  try {
    const [waiting, active, completed, failed, delayed] = await Promise.all([
      app.downloadQueue.getWaitingCount(),
      app.downloadQueue.getActiveCount(),
      app.downloadQueue.getCompletedCount(),
      app.downloadQueue.getFailedCount(),
      app.downloadQueue.getDelayedCount(),
    ]);
    queueDetails = {
      counts: { waiting, active, completed, failed, delayed },
    };
  } catch (e) {
    queueDetails = {
      skippedReason: "queue inspect failed",
      error: e instanceof Error ? e.message : String(e),
    };
  }

  /** Recent job failures */
  let failuresSummary: Record<string, unknown>;
  try {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const failed24h = await app.prisma.downloadJob.count({
      where: { status: "failed", updatedAt: { gte: since } },
    });
    const groupedRaw = await app.prisma.downloadJob.groupBy({
      by: ["error"],
      where: { status: "failed", updatedAt: { gte: since }, error: { not: null } },
      _count: { _all: true },
    });
    const grouped = [...groupedRaw].sort((a, b) => b._count._all - a._count._all).slice(0, 8);
    const latestFail = await app.prisma.downloadJob.findFirst({
      where: { status: "failed" },
      orderBy: { updatedAt: "desc" },
      select: { updatedAt: true, error: true },
    });
    failuresSummary = {
      failedJobsLast24h: failed24h,
      topErrors: grouped.map((g) => ({
        codeOrMessage: g.error ? String(g.error).slice(0, 160) : null,
        count: g._count._all,
      })),
      latestFailedAt: latestFail?.updatedAt.toISOString() ?? null,
    };
  } catch (e) {
    failuresSummary = {
      skippedReason: "job stats query failed",
      error: e instanceof Error ? e.message : String(e),
    };
  }

  const retentionRaw = process.env.MEDIA_RETENTION_MINUTES?.trim();
  const retentionParsed = retentionRaw ? Number(retentionRaw) : NaN;
  const cleanupConfigured =
    Number.isFinite(retentionParsed) && retentionParsed > 0;

  const storageUsedHuman = storageBytes != null ? formatBytes(storageBytes) : "unknown";

  const ytDlpOk = ytDlpProbe.ok;
  const ffmpegOk = ffmpegProbe.ok;
  const storageOk = storageExists && writable.ok;

  const downloadsReady = !!(storageOk && ytDlpOk && ffmpegOk);

  if (!dbOk) pushWarn("Database is down");
  if (!redisOk) pushWarn("Redis is down");

  /** Roll up status */
  let status: OverallStatus = "healthy";
  const critical =
    !storageOk ||
    !ytDlpOk ||
    !dbOk ||
    !redisOk ||
    (diskUsagePercent != null && diskUsagePercent >= 90);

  const warning =
    !cookiesOk ||
    !youtubeReady ||
    !ffmpegProbe.ok ||
    !ffprobeProbe.ok ||
    (diskUsagePercent != null && diskUsagePercent >= 80 && diskUsagePercent < 90) ||
    mainWarnings.length > 0;

  if (critical) status = "critical";
  else if (warning) status = "warning";

  const queueInspectOk = "counts" in queueDetails && queueDetails.counts != null;
  const failuresInspectOk = !(
    "skippedReason" in failuresSummary && failuresSummary.skippedReason != null
  );

  const checks: DiagnosticsResult["checks"] = {
    app: {
      ok: true,
      status: "healthy",
      summary: "Runtime snapshot",
      details: {
        NODE_ENV: config.NODE_ENV,
        packageVersion: pkgVersion,
        timeUtc: new Date().toISOString(),
        uptimeSeconds: Math.floor(process.uptime()),
        pid: process.pid,
        hostname: os.hostname(),
        memory: process.memoryUsage(),
      },
    },
    tools: {
      ok: ytDlpOk && ffmpegOk && ffprobeProbe.ok && nodeAvailable,
      status:
        ytDlpOk && ffmpegOk && ffprobeProbe.ok && nodeAvailable
          ? "healthy"
          : !ytDlpOk || !nodeAvailable
            ? "critical"
            : "warning",
      summary: "External CLI tools",
      details: {
        ytDlp: ytDlpProbe,
        ffmpeg: ffmpegProbe,
        ffprobe: ffprobeProbe,
        nodeVersion: nodeVerProbe,
        nodePath: nodePathProbe,
        ytDlpEjsInstalled: { ok: ytDlpEjsInstalled, value: ytDlpEjsInstalled ? "true" : "false", error: ytEjsProbe.error },
        curlCffiInstalled: {
          ok: curlCffiInstalled,
          value: curlCffiInstalled ? "true" : "false",
          error: curlCffiProbe.error,
        },
      },
    },
    youtubeReadiness: {
      ok: youtubeReady,
      status: youtubeReady ? "healthy" : "warning",
      summary: youtubeReady ? "YouTube solver prerequisites present" : "YouTube solver prerequisites incomplete",
      details: youtubeReadinessDetails,
    },
    cookies: {
      ok: cookiesOk,
      status: cookiesConfigured && cookiesOk ? "healthy" : cookiesConfigured ? "warning" : "warning",
      summary: cookiesOk ? "Cookies file usable" : "Cookies missing or invalid",
      details: {
        ...cookieDetails,
        youtubeOrGoogleCookiesDetected,
      },
    },
    storage: {
      ok: storageOk,
      status: storageOk ? "healthy" : "critical",
      summary: storageOk ? "Storage directory usable" : "Storage unavailable",
      details: {
        storageDirSafe: safePathForDiagnostics(storageDir),
        exists: storageExists,
        writable: writable.ok,
        writableError: writable.error,
        fileCount: storageFileCount,
        fileCountCapped: storageFileCount >= MAX_FILE_COUNT_WALK,
        totalBytes: storageBytes,
        totalHuman: storageUsedHuman,
        df: df
          ? {
              totalKb: df.totalKb,
              usedKb: df.usedKb,
              availKb: df.availKb,
              usePercent: df.usePercent,
            }
          : null,
        dfParseNote: df?.error ?? null,
      },
    },
    cleanup: {
      ok: cleanupConfigured,
      status: cleanupConfigured ? "healthy" : "warning",
      summary: cleanupConfigured
        ? `Retention configured (${retentionParsed} minutes)`
        : "MEDIA_RETENTION_MINUTES not set in this process",
      details: {
        MEDIA_RETENTION_MINUTES: retentionRaw ?? null,
        retentionMinutesParsed: Number.isFinite(retentionParsed) ? retentionParsed : null,
        note:
          "Cleanup runs in a separate Docker service (see docker-compose.prod.yml); API container may omit MEDIA_RETENTION_MINUTES.",
      },
    },
    database: {
      ok: dbOk,
      status: dbOk ? "healthy" : "critical",
      summary: dbOk ? "PostgreSQL reachable" : "PostgreSQL unreachable",
      details: {
        connected: dbOk,
        error: dbError,
      },
    },
    redis: {
      ok: redisOk,
      status: redisOk ? "healthy" : "critical",
      summary: redisOk ? "Redis PING ok" : "Redis unreachable",
      details: {
        pingOk: redisOk,
        error: redisError,
      },
    },
    queues: {
      ok: queueInspectOk,
      status: queueInspectOk ? "healthy" : "skipped",
      summary: queueInspectOk ? "Download queue snapshot" : "Queue metrics unavailable",
      details: queueDetails,
    },
    recentFailures: {
      ok: failuresInspectOk,
      status: failuresInspectOk ? "healthy" : "skipped",
      summary: failuresInspectOk ? "Download failures (24h)" : "Failure stats unavailable",
      details: failuresSummary,
    },
  };

  const ok = status === "healthy";

  return {
    ok,
    status,
    shortcuts: {
      downloadsReady,
      storageOk,
      cookiesOk,
      youtubeReady,
      ytDlpOk,
      ffmpegOk,
      nodeJsRuntimeOk: nodeAvailable,
      cleanupConfigured,
      diskUsagePercent,
      storageFileCount,
      storageUsedHuman,
      mainWarnings,
    },
    checks,
  };
}

export function diagnosticsToText(d: DiagnosticsResult): string {
  const s = d.shortcuts;
  const lines: string[] = [];
  lines.push(`LinkClip diagnostics: ${d.status}`);
  lines.push(`Downloads: ${s.downloadsReady ? "OK" : "FAIL"}`);
  const df = d.checks.storage?.details as { df?: { availKb?: number | null; usePercent?: number | null } } | undefined;
  const availKb = df?.df?.availKb;
  const availHuman = availKb != null ? formatBytes(availKb * 1024) : "?";
  lines.push(`Storage: ${s.storageOk ? "OK" : "FAIL"} ${s.storageUsedHuman} used, ${availHuman} free`);
  const ck = d.checks.cookies?.details as {
    lineCount?: number | null;
    domains?: CookieDomains | null;
    validNetscapeLooking?: boolean;
  };
  const dom = ck?.domains;
  const domParts: string[] = [];
  if (dom?.hasInstagramCookies) domParts.push("instagram");
  if (dom?.hasTikTokCookies) domParts.push("tiktok");
  if (dom?.hasFacebookCookies) domParts.push("facebook");
  if (dom?.hasYouTubeOrGoogleCookies) domParts.push("youtube/google");
  const cookieLine =
    s.cookiesOk && ck?.lineCount != null
      ? `OK ${ck.lineCount} lines; ${domParts.length ? domParts.join("/") + " detected" : "no known domains in sample"}`
      : s.cookiesOk
        ? "OK"
        : "FAIL";
  lines.push(`Cookies: ${cookieLine}`);
  const yt = (d.checks.tools?.details as { ytDlp?: ToolProbe })?.ytDlp?.value ?? "?";
  lines.push(`yt-dlp: ${s.ytDlpOk ? "OK" : "FAIL"} ${yt}`);
  const nv = (d.checks.youtubeReadiness?.details as { nodeVersion?: string | null })?.nodeVersion ?? "?";
  const ejs = (d.checks.youtubeReadiness?.details as { ytDlpEjsInstalled?: boolean })?.ytDlpEjsInstalled;
  lines.push(`YouTube runtime: ${s.youtubeReady ? "OK" : "FAIL"} node ${nv}${ejs ? " + yt-dlp-ejs" : ""}`);
  const ff = (d.checks.tools?.details as { ffmpeg?: ToolProbe })?.ffmpeg?.value ?? "?";
  lines.push(`ffmpeg: ${s.ffmpegOk ? "OK" : "FAIL"} ${ff?.replace(/^ffmpeg version\s+/i, "").slice(0, 32) ?? ""}`);
  lines.push(`DB: ${(d.checks.database?.details as { connected?: boolean })?.connected ? "OK" : "FAIL"}`);
  lines.push(`Redis: ${(d.checks.redis?.details as { pingOk?: boolean })?.pingOk ? "OK" : "FAIL"}`);
  const ret = (d.checks.cleanup?.details as { retentionMinutesParsed?: number | null })?.retentionMinutesParsed;
  lines.push(
    `Cleanup: ${s.cleanupConfigured ? "OK" : "N/A"}${ret != null ? ` retention ${ret} minutes` : ""}`
  );
  lines.push(s.mainWarnings.length ? `Warnings: ${s.mainWarnings.join("; ")}` : "Warnings: none");
  return lines.join("\n");
}
