/**
 * YouTube PO Token Provider spike diagnostic.
 * Run: npm run diag:youtube-pot
 */
import dotenv from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  DEFAULT_SMOKE_URL,
  printCompactTable,
  redactSensitiveDiagText,
  resolveYoutubeDiagDelayMs,
  resolveYoutubeDiagUrls,
  safeHost,
  safeYouTubeVideoId,
  sleep,
  summarizeClassifications,
  truthyEnv,
  type YoutubeDiagClassification,
} from "./youtubeDiagShared";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

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

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const verbose = truthyEnv("YOUTUBE_DIAG_VERBOSE");
  const { urls, usedDefaultSmoke } = resolveYoutubeDiagUrls(backendRoot);
  const delayMs = resolveYoutubeDiagDelayMs(urls.length);

  const { config } = await import("../src/config");
  const { codes } = await import("../src/types/errors");
  const {
    fetchMetadataJson,
    YtdlpMetadataError,
    ytDlpCookiesOperationalFlags,
  } = await import("../src/services/ytdlp");
  const { mapYtdlpAnalyzeFailure } = await import("../src/services/ytdlpAnalyzeErrors");
  const {
    detectBgutilPotPluginInstalled,
    probePotProviderReachable,
    resolveProviderBaseUrl,
    validatePoTokenConfigWhenEnabled,
    ytDlpPoTokenOperationalFlags,
  } = await import("../src/services/ytdlpPoToken");
  type YtdlpStderrKind = import("../src/services/ytdlp").YtdlpStderrKind;

  const poFlags = ytDlpPoTokenOperationalFlags({ isYouTube: true });
  const plugin = detectBgutilPotPluginInstalled();
  const providerUrl = resolveProviderBaseUrl();
  const providerProbe = config.ytdlpPoTokenEnabled
    ? await probePotProviderReachable(providerUrl)
    : { ok: false, detail: "disabled" };
  const validation = validatePoTokenConfigWhenEnabled();

  console.info("LinkClip YouTube PO Token diagnostic\n");
  console.info("--- config ---");
  console.info(`poTokenEnabled: ${poFlags.poTokenEnabled}`);
  console.info(`providerUrl configured: ${poFlags.providerConfigured ? "yes" : "no"}`);
  console.info(`poTokenClient: ${poFlags.poTokenClient}`);
  console.info(`providerMode: ${poFlags.providerMode}`);
  console.info(`cacheEnabled: ${config.ytdlpPoTokenCacheEnabled}`);
  console.info(`plugin installed: ${plugin.installed ? "yes" : "no"} (${plugin.detail})`);
  console.info(
    `provider reachable: ${providerProbe.ok ? "yes" : "no"}${config.ytdlpPoTokenEnabled ? ` (${providerProbe.detail})` : ""}`
  );

  if (config.ytdlpPoTokenEnabled) {
    if (!validation.ok) {
      console.error("\nPO Token enabled but configuration incomplete:");
      for (const issue of validation.issues) console.error(`  - ${issue}`);
      process.exit(1);
    }
    if (!providerProbe.ok) {
      console.error("\nPO Token enabled but provider is not reachable.");
      console.error("Start bgutil HTTP server or set YTDLP_PO_TOKEN_PROVIDER_URL correctly.");
      process.exit(1);
    }
  } else {
    console.info("\nPO Token is disabled (YTDLP_PO_TOKEN_ENABLED=false).");
    console.info("Set YTDLP_PO_TOKEN_ENABLED=true to run an enabled smoke test.");
    console.info(`Running metadata smoke with current config (${usedDefaultSmoke ? "default smoke URL" : `${urls.length} URL(s)`})...\n`);
  }

  const cookieFlags = ytDlpCookiesOperationalFlags();

  function resolveFailure(
    kind: YtdlpStderrKind,
    urlHost: string,
    stderrTail: string
  ): { classification: YoutubeDiagClassification; code: string } {
    if (kind === "network_error" || kind === "rate_limited") {
      return {
        classification: "network_or_proxy",
        code: kind === "rate_limited" ? codes.RATE_LIMITED : "NETWORK_ERROR",
      };
    }
    const mapped = mapYtdlpAnalyzeFailure(kind, urlHost, stderrTail);
    if (mapped) {
      return {
        classification: mapped.classification as YoutubeDiagClassification,
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
        return { classification: "auth_required", code: codes.YOUTUBE_AUTH_REQUIRED };
      case "geo_restricted":
        return { classification: "geo_restricted", code: codes.YOUTUBE_GEO_RESTRICTED };
      case "no_formats_found":
        return { classification: "no_formats_found", code: codes.NO_DOWNLOADABLE_FORMATS };
      default:
        return { classification: "unknown", code: codes.ANALYZE_FAILED };
    }
  }

  const testUrls = config.ytdlpPoTokenEnabled ? urls : [urls[0] ?? DEFAULT_SMOKE_URL];
  const rows: {
    outcome: "success" | "fail";
    classification: YoutubeDiagClassification;
    code: string;
    cells: string[];
  }[] = [];
  let anyFail = false;

  for (let i = 0; i < testUrls.length; i++) {
    if (i > 0 && delayMs > 0) await sleep(delayMs);
    const url = testUrls[i]!;
    const host = safeHost(url);
    const videoId = safeYouTubeVideoId(url);
    const started = Date.now();

    try {
      const meta = await fetchMetadataJson(url, { logFailures: verbose });
      const id = meta.id && /^[\w-]{6,}$/.test(meta.id) ? meta.id : videoId;
      rows.push({
        outcome: "success",
        classification: "success",
        code: "OK",
        cells: [
          String(i + 1),
          host,
          id,
          "analyze",
          poFlags.poTokenEnabled ? "yes" : "no",
          poFlags.poTokenUsed ? "yes" : "no",
          poFlags.poTokenClient,
          providerProbe.ok ? "yes" : "no",
          "success",
          "OK",
          String(Date.now() - started),
        ],
      });
    } catch (err) {
      anyFail = true;
      let classification: YoutubeDiagClassification = "unknown";
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
        outcome: "fail",
        classification,
        code,
        cells: [
          String(i + 1),
          host,
          videoId,
          "analyze",
          poFlags.poTokenEnabled ? "yes" : "no",
          poFlags.poTokenUsed ? "yes" : "no",
          poFlags.poTokenClient,
          providerProbe.ok ? "yes" : "no",
          classification,
          code,
          String(Date.now() - started),
        ],
      });

      if (verbose && stderrTail) {
        console.info(`--- verbose stderr (row ${i + 1}, redacted) ---`);
        console.info(redactSensitiveDiagText(stderrTail));
        console.info("--- end stderr ---\n");
      }
    }
  }

  console.info(
    `\nURLs: ${testUrls.length} | cookiesConfigured=${cookieFlags.hasCookiesConfigured} | delayMs=${delayMs}\n`
  );

  const header = [
    "idx",
    "host",
    "videoId",
    "mode",
    "poEnabled",
    "poUsed",
    "poClient",
    "providerOk",
    "classification",
    "code",
    "durationMs",
  ];
  printCompactTable(
    header,
    rows.map((r) => r.cells)
  );

  const summary = summarizeClassifications(rows);
  console.info(
    `\nSummary: success=${summary.success} auth_required=${summary.auth_required} geo_restricted=${summary.geo_restricted} no_formats_found=${summary.no_formats_found} format_unavailable=${summary.format_unavailable} network_or_proxy=${summary.network_or_proxy} unknown=${summary.unknown}`
  );

  if (anyFail && config.ytdlpPoTokenEnabled) process.exit(1);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
