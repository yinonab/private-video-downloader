/**
 * Controlled YouTube analyze/metadata matrix — metadata-only, rate-conscious probing.
 * Run: npm run diag:youtube-matrix
 *
 * Env:
 *   YOUTUBE_DIAG_URLS          — comma/newline-separated URLs
 *   YOUTUBE_DIAG_URLS_FILE     — path to file (one URL per line; # comments ok)
 *   YOUTUBE_DIAG_MAX_URLS      — cap when a list is supplied (default 5)
 *   YOUTUBE_DIAG_VERBOSE=1     — print redacted stderr tails on failure
 *   YOUTUBE_DIAG_DELAY_MS      — pause between URLs (default 2000 when >1 URL)
 */
import dotenv from "dotenv";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/** Stable public video — used only when no custom URLs are supplied. */
const DEFAULT_SMOKE_URL = "https://www.youtube.com/watch?v=jNQXAC9IVRw";

const DEFAULT_LIST_CAP = 5;

type MatrixClassification =
  | "success"
  | "auth_required"
  | "geo_restricted"
  | "no_formats_found"
  | "format_unavailable"
  | "network_or_proxy"
  | "unknown";

type MatrixRow = {
  index: number;
  host: string;
  videoId: string;
  mode: "analyze";
  cookiesConfigured: boolean;
  tempCookieUsed: boolean;
  outcome: "success" | "fail";
  classification: MatrixClassification;
  code: string;
  durationMs: number;
};

function ensureDiagEnv(): void {
  const stubs: Record<string, string> = {
    DATABASE_URL: "postgresql://diag/diag",
    REDIS_URL: "redis://127.0.0.1:6379",
    STORAGE_DIR: path.join(backendRoot, "storage"),
    ADMIN_TOKEN: "diag-admin-token",
    DEVICE_TOKEN_SECRET: "diag-device-token-secret",
  };
  for (const [k, v] of Object.entries(stubs)) {
    if (!process.env[k]?.trim()) process.env[k] = v;
  }
}

function truthyEnv(name: string): boolean {
  const v = process.env[name]?.trim().toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

function parseUrlList(raw: string): string[] {
  return raw
    .split(/[\r\n,]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("#"));
}

function readUrlsFromFile(filePath: string): string[] {
  const resolved = path.isAbsolute(filePath) ? filePath : path.join(backendRoot, filePath);
  if (!fs.existsSync(resolved)) {
    console.error(`YOUTUBE_DIAG_URLS_FILE not found: ${resolved}`);
    process.exit(1);
  }
  return parseUrlList(fs.readFileSync(resolved, "utf8"));
}

function resolveDiagUrls(): { urls: string[]; usedDefaultSmoke: boolean } {
  const fromEnv = process.env.YOUTUBE_DIAG_URLS?.trim()
    ? parseUrlList(process.env.YOUTUBE_DIAG_URLS)
    : [];
  const fromFile = process.env.YOUTUBE_DIAG_URLS_FILE?.trim()
    ? readUrlsFromFile(process.env.YOUTUBE_DIAG_URLS_FILE.trim())
    : [];

  const merged = [...fromFile, ...fromEnv];
  const deduped: string[] = [];
  const seen = new Set<string>();
  for (const u of merged) {
    const key = u.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(u);
  }

  if (deduped.length === 0) {
    return { urls: [DEFAULT_SMOKE_URL], usedDefaultSmoke: true };
  }

  const maxRaw = process.env.YOUTUBE_DIAG_MAX_URLS?.trim();
  const cap = maxRaw ? Math.max(1, parseInt(maxRaw, 10) || DEFAULT_LIST_CAP) : DEFAULT_LIST_CAP;
  return { urls: deduped.slice(0, cap), usedDefaultSmoke: false };
}

function safeHost(urlString: string): string {
  try {
    return new URL(urlString).hostname.toLowerCase();
  } catch {
    return "invalid";
  }
}

/** Best-effort YouTube id extraction — never logs the full URL. */
function safeYouTubeVideoId(urlString: string): string {
  try {
    const u = new URL(urlString);
    const host = u.hostname.toLowerCase();
    if (host === "youtu.be") {
      const id = u.pathname.replace(/^\//, "").split("/")[0];
      return id && /^[\w-]{6,}$/.test(id) ? id : "-";
    }
    if (host.includes("youtube.com")) {
      const v = u.searchParams.get("v");
      if (v && /^[\w-]{6,}$/.test(v)) return v;
      const shorts = u.pathname.match(/\/shorts\/([\w-]{6,})/);
      if (shorts?.[1]) return shorts[1];
      const embed = u.pathname.match(/\/embed\/([\w-]{6,})/);
      if (embed?.[1]) return embed[1];
    }
  } catch {
    /* ignore */
  }
  return "-";
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Redact secrets before optional verbose stderr logging. */
function redactSensitiveDiagText(text: string): string {
  let s = text;
  s = s.replace(/\b(?:PO Token|po_token|visitor_data)[^\s]*/gi, "[REDACTED_TOKEN]");
  s = s.replace(/https?:\/\/[^\s:@]+:[^\s@]+@[^\s]+/gi, "[REDACTED_PROXY_URL]");
  s = s.replace(/(proxy(?:\s*url)?\s*[=:]\s*)\S+/gi, "$1[REDACTED]");
  s = s.replace(/(--cookies(?:-from-browser)?\s+)\S+/gi, "$1[REDACTED_PATH]");
  s = s.replace(/^[^\t]+\tTRUE\t[^\t]+\t(TRUE|FALSE)\t\d+\t[^\t]+\t[^\r\n]+$/gm, "[REDACTED_COOKIE_ROW]");
  s = s.replace(/(#(?:HttpOnly_)?[^\s]+\s+)[^\s]+(\s+[^\r\n]+)/g, "$1[REDACTED]$2");
  return s;
}

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const verbose = truthyEnv("YOUTUBE_DIAG_VERBOSE");
  const { urls, usedDefaultSmoke } = resolveDiagUrls();
  const delayMs = (() => {
    const raw = process.env.YOUTUBE_DIAG_DELAY_MS?.trim();
    if (raw) return Math.max(0, parseInt(raw, 10) || 0);
    return urls.length > 1 ? 2000 : 0;
  })();

  const { codes } = await import("../src/types/errors");
  const {
    fetchMetadataJson,
    YtdlpMetadataError,
    ytDlpCookiesOperationalFlags,
  } = await import("../src/services/ytdlp");
  const { mapYtdlpAnalyzeFailure } = await import("../src/services/ytdlpAnalyzeErrors");
  type YtdlpStderrKind = import("../src/services/ytdlp").YtdlpStderrKind;

  const cookieFlags = ytDlpCookiesOperationalFlags();

  function resolveFailure(
    kind: YtdlpStderrKind,
    urlHost: string,
    stderrTail: string
  ): { classification: MatrixClassification; code: string } {
    if (kind === "network_error" || kind === "rate_limited") {
      return {
        classification: "network_or_proxy",
        code: kind === "rate_limited" ? codes.RATE_LIMITED : "NETWORK_ERROR",
      };
    }

    const mapped = mapYtdlpAnalyzeFailure(kind, urlHost, stderrTail);
    if (mapped) {
      return {
        classification: mapped.classification as MatrixClassification,
        code: mapped.code,
      };
    }

    switch (kind) {
      case "format_unavailable":
        return {
          classification: "format_unavailable",
          code: codes.LINKCLIP_ERR_ANALYZE_METADATA_UNAVAILABLE,
        };
      case "auth_required":
        return { classification: "auth_required", code: codes.ANALYZE_FAILED };
      case "geo_restricted":
        return { classification: "geo_restricted", code: codes.YOUTUBE_GEO_RESTRICTED };
      case "no_formats_found":
        return { classification: "no_formats_found", code: codes.NO_DOWNLOADABLE_FORMATS };
      default:
        return { classification: "unknown", code: codes.ANALYZE_FAILED };
    }
  }

  console.info("LinkClip YouTube baseline matrix (analyze/metadata only)\n");
  console.info(
    `URLs: ${urls.length}${usedDefaultSmoke ? " (default smoke)" : ""} | cookiesConfigured=${cookieFlags.hasCookiesConfigured} | tempCookieUsed=${cookieFlags.tempCookieUsed} | delayMs=${delayMs}\n`
  );

  const rows: MatrixRow[] = [];
  let anyFail = false;

  for (let i = 0; i < urls.length; i++) {
    if (i > 0 && delayMs > 0) await sleep(delayMs);

    const url = urls[i]!;
    const host = safeHost(url);
    const videoId = safeYouTubeVideoId(url);
    const started = Date.now();

    try {
      const meta = await fetchMetadataJson(url);
      const id = meta.id && /^[\w-]{6,}$/.test(meta.id) ? meta.id : videoId;
      rows.push({
        index: i + 1,
        host,
        videoId: id,
        mode: "analyze",
        cookiesConfigured: cookieFlags.hasCookiesConfigured,
        tempCookieUsed: cookieFlags.tempCookieUsed,
        outcome: "success",
        classification: "success",
        code: "OK",
        durationMs: Date.now() - started,
      });
    } catch (err) {
      anyFail = true;
      let classification: MatrixClassification = "unknown";
      let code = codes.ANALYZE_FAILED;
      let stderrTail = "";

      if (err instanceof YtdlpMetadataError) {
        stderrTail = err.stderrTail;
        const resolved = resolveFailure(err.classification, host, stderrTail);
        classification = resolved.classification;
        code = resolved.code;
      } else {
        const msg = err instanceof Error ? err.message : String(err);
        if (/ENOENT|not found in PATH|spawn yt-dlp/i.test(msg)) {
          classification = "network_or_proxy";
          code = "YTDLP_MISSING";
        }
        stderrTail = msg.slice(0, 2000);
      }

      rows.push({
        index: i + 1,
        host,
        videoId,
        mode: "analyze",
        cookiesConfigured: cookieFlags.hasCookiesConfigured,
        tempCookieUsed: cookieFlags.tempCookieUsed,
        outcome: "fail",
        classification,
        code,
        durationMs: Date.now() - started,
      });

      if (verbose && stderrTail) {
        console.info(`--- verbose stderr (row ${i + 1}, redacted) ---`);
        console.info(redactSensitiveDiagText(stderrTail));
        console.info("--- end stderr ---\n");
      }
    }
  }

  const header = [
    "idx",
    "host",
    "videoId",
    "mode",
    "cookies",
    "tempCookie",
    "result",
    "classification",
    "code",
    "durationMs",
  ];
  const widths = header.map((h) => h.length);
  const cells = rows.map((r) => [
    String(r.index),
    r.host,
    r.videoId,
    r.mode,
    r.cookiesConfigured ? "yes" : "no",
    r.tempCookieUsed ? "yes" : "no",
    r.outcome,
    r.classification,
    r.code,
    String(r.durationMs),
  ]);
  for (const row of cells) {
    row.forEach((cell, ci) => {
      widths[ci] = Math.max(widths[ci]!, cell.length);
    });
  }

  const fmt = (row: string[]) => row.map((cell, ci) => cell.padEnd(widths[ci]!)).join("  ");
  console.info(fmt(header));
  console.info(widths.map((w) => "-".repeat(w)).join("  "));
  for (const row of cells) {
    console.info(fmt(row));
  }

  const okCount = rows.filter((r) => r.outcome === "success").length;
  console.info(`\nSummary: ${okCount}/${rows.length} succeeded`);

  if (anyFail) process.exit(1);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
