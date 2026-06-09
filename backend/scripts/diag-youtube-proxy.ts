/**
 * YouTube proxy/egress diagnostic — metadata-only, rate-conscious probing.
 * Run: npm run diag:youtube-proxy
 */
import dotenv from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  applyYoutubeDiagYtDlpMode,
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
  const diagMode = applyYoutubeDiagYtDlpMode();

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
  const { probePotProviderReachable, ytDlpPoTokenOperationalFlags } = await import(
    "../src/services/ytdlpPoToken"
  );
  const {
    getRedactedProxyInfo,
    probeProxyViaYtDlp,
    validateProxyConfigWhenEnabled,
    ytDlpProxyOperationalFlags,
  } = await import("../src/services/ytdlpProxy");
  type YtdlpStderrKind = import("../src/services/ytdlp").YtdlpStderrKind;

  const proxyInfo = getRedactedProxyInfo();
  const proxyValidation = validateProxyConfigWhenEnabled();
  const cookieFlags = ytDlpCookiesOperationalFlags();
  const poFlags = ytDlpPoTokenOperationalFlags({ isYouTube: true });
  const proxyFlags = ytDlpProxyOperationalFlags({ isYouTube: true, proxyReason: "diagnostic" });
  const providerProbe = poFlags.poTokenEnabled
    ? await probePotProviderReachable()
    : { ok: false, detail: "disabled" };

  console.info("LinkClip YouTube proxy/egress diagnostic\n");
  console.info("--- config ---");
  console.info(`diagMode: ${diagMode}`);
  console.info(`proxyEnabled: ${proxyFlags.proxyEnabled}`);
  console.info(`proxyConfigured: ${proxyInfo.configured && proxyInfo.valid ? "yes" : "no"}`);
  console.info(`proxyHost: ${proxyInfo.host ?? "-"}`);
  console.info(`proxyUrlRedacted: ${proxyInfo.proxyUrlRedacted}`);
  console.info(`proxyProviderLabel: ${proxyInfo.providerLabel ?? "-"}`);
  console.info(`youtubeOnly: ${proxyFlags.youtubeOnly}`);
  console.info(`proxyOnAuthRequired: ${config.ytdlpProxyOnAuthRequired}`);
  console.info(`proxyOnGeoRestricted: ${config.ytdlpProxyOnGeoRestricted}`);
  console.info(`poEnabled: ${poFlags.poTokenEnabled}`);
  console.info(`poClient: ${poFlags.poTokenClient}`);
  console.info(`providerOk: ${providerProbe.ok ? "yes" : "no"}`);

  if (config.ytdlpProxyEnabled) {
    if (!proxyValidation.ok) {
      console.error("\nProxy enabled but configuration invalid:");
      for (const issue of proxyValidation.issues) console.error(`  - ${issue}`);
      process.exit(1);
    }
    const proxyProbe = await probeProxyViaYtDlp();
    console.info(`proxyConnectivity: ${proxyProbe.ok ? "yes" : "no"} (${proxyProbe.detail})`);
    if (!proxyProbe.ok) {
      console.error("\nProxy enabled but connectivity probe failed.");
      process.exit(1);
    }
  } else {
    console.info("\nProxy is disabled (YTDLP_PROXY_ENABLED=false).");
    console.info("Set YTDLP_PROXY_ENABLED=true and YTDLP_PROXY_URL in server env to test egress.");
    console.info(`Running metadata smoke (${usedDefaultSmoke ? "default URL" : `${urls.length} URL(s)`}) with current flags...\n`);
  }

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

  const testUrls = config.ytdlpProxyEnabled ? urls : [urls[0]!];
  const rows: {
    outcome: "success" | "fail";
    classification: YoutubeDiagClassification;
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
        cells: [
          String(i + 1),
          host,
          id,
          "analyze",
          cookieFlags.hasCookiesConfigured ? "yes" : "no",
          cookieFlags.tempCookieUsed ? "yes" : "no",
          poFlags.poTokenEnabled ? "yes" : "no",
          poFlags.poTokenUsed ? "yes" : "no",
          proxyFlags.proxyEnabled ? "yes" : "no",
          proxyFlags.proxyUsed ? "yes" : "no",
          proxyFlags.proxyReason ?? "direct",
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
        cells: [
          String(i + 1),
          host,
          videoId,
          "analyze",
          cookieFlags.hasCookiesConfigured ? "yes" : "no",
          cookieFlags.tempCookieUsed ? "yes" : "no",
          poFlags.poTokenEnabled ? "yes" : "no",
          poFlags.poTokenUsed ? "yes" : "no",
          proxyFlags.proxyEnabled ? "yes" : "no",
          proxyFlags.proxyUsed ? "yes" : "no",
          proxyFlags.proxyReason ?? "direct",
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

  const header = [
    "idx",
    "host",
    "videoId",
    "mode",
    "cookies",
    "tempCookie",
    "poEnabled",
    "poUsed",
    "proxyEnabled",
    "proxyUsed",
    "proxyReason",
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

  if (anyFail && config.ytdlpProxyEnabled) process.exit(1);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
