import { spawn } from "node:child_process";
import { config } from "../config";
import { hostnameIsYouTube } from "./urlSafety";
import { redactProxyUrl, parseProxyUrl, type RedactedProxyInfo } from "./ytdlpProxyRedaction";
import type { YtdlpPoTokenContext } from "./ytdlpPoToken";
import type { YtdlpStderrKind } from "./ytdlp";

export type YtdlpProxyReason = "direct" | "diagnostic" | "geo_retry" | "auth_retry" | "enabled";

export type YtdlpProxyContext = YtdlpPoTokenContext & {
  proxyReason?: YtdlpProxyReason;
  forceProxy?: boolean;
};

export type YtdlpProxyOperationalFlags = {
  proxyEnabled: boolean;
  proxyUsed: boolean;
  proxyReason?: string;
  proxyHost?: string;
  proxyScheme?: string;
  proxyProviderLabel?: string;
  proxyUrlRedacted: string;
  youtubeOnly: boolean;
};

const YT_DLP = process.env.YT_DLP_PATH || "yt-dlp";

function proxyAppliesToContext(context: YtdlpProxyContext): boolean {
  if (!config.ytdlpProxyEnabled) return false;
  if (!config.ytdlpProxyUrl.trim()) return false;
  if (!parseProxyUrl(config.ytdlpProxyUrl)) return false;
  if (config.ytdlpProxyYoutubeOnly && !context.isYouTube) return false;
  return true;
}

/** Safe operational flags — never includes raw proxy URL or credentials. */
export function ytDlpProxyOperationalFlags(context?: Pick<YtdlpProxyContext, "isYouTube" | "proxyReason">): YtdlpProxyOperationalFlags {
  const redacted = redactProxyUrl(config.ytdlpProxyUrl, config.ytdlpProxyProviderLabel);
  const applies = context ? proxyAppliesToContext({ ...context, operation: "analyze", urlHost: "", isYouTube: context.isYouTube ?? false }) : config.ytdlpProxyEnabled && redacted.valid;
  return {
    proxyEnabled: config.ytdlpProxyEnabled,
    proxyUsed: applies,
    proxyReason: context?.proxyReason,
    proxyHost: redacted.host,
    proxyScheme: redacted.scheme,
    proxyProviderLabel: redacted.providerLabel,
    proxyUrlRedacted: redacted.proxyUrlRedacted,
    youtubeOnly: config.ytdlpProxyYoutubeOnly,
  };
}

export function getRedactedProxyInfo(): RedactedProxyInfo {
  return redactProxyUrl(config.ytdlpProxyUrl, config.ytdlpProxyProviderLabel);
}

/**
 * Append `--proxy` when enabled and applicable. Never logs the raw URL.
 * No-op when disabled, URL missing/invalid, or non-YouTube with youtubeOnly=true.
 */
export function withYtDlpProxyArgs(args: string[], context: YtdlpProxyContext): string[] {
  if (!proxyAppliesToContext(context)) {
    return [...args];
  }

  const proxyUrl = config.ytdlpProxyUrl.trim();
  const result = [...args];
  const jsIdx = result.indexOf("--js-runtimes");
  const insertAt = jsIdx >= 0 ? jsIdx + 2 : 0;
  result.splice(insertAt, 0, "--proxy", proxyUrl);
  return result;
}

/** PO args first, then proxy — preserves cookies + JS runtime ordering. */
export function applyYtDlpYouTubeTransportArgs(
  args: string[],
  context: YtdlpProxyContext,
  withPo: (a: string[], c: YtdlpPoTokenContext) => string[]
): string[] {
  const poCtx: YtdlpPoTokenContext = context;
  return withYtDlpProxyArgs(withPo(args, poCtx), context);
}

export function ytdlpProxyContextFromUrl(
  url: string,
  operation: "analyze" | "download",
  extra?: Partial<YtdlpProxyContext>
): YtdlpProxyContext {
  let urlHost = "unknown";
  try {
    urlHost = new URL(url).hostname.toLowerCase();
  } catch {
    /* ignore */
  }
  const isYouTube = hostnameIsYouTube(urlHost);
  const proxyReason: YtdlpProxyReason =
    extra?.proxyReason ??
    (config.ytdlpProxyEnabled && isYouTube && config.ytdlpProxyUrl ? "enabled" : "direct");

  return {
    operation,
    urlHost,
    isYouTube,
    proxyReason,
    ...extra,
  };
}

/** Whether a failed classification may trigger a single proxy retry (production opt-in). */
export function shouldRetryWithProxy(classification: YtdlpStderrKind, context: YtdlpProxyContext): boolean {
  if (!config.ytdlpProxyEnabled || !config.ytdlpProxyUrl.trim()) return false;
  if (!context.isYouTube) return false;
  if (context.proxyReason && context.proxyReason !== "direct" && context.proxyReason !== "enabled") {
    return false;
  }
  if (classification === "geo_restricted" && config.ytdlpProxyOnGeoRestricted) return true;
  if (classification === "auth_required" && config.ytdlpProxyOnAuthRequired) return true;
  return false;
}

export function validateProxyConfigWhenEnabled(): { ok: boolean; issues: string[] } {
  if (!config.ytdlpProxyEnabled) {
    return { ok: true, issues: [] };
  }
  const issues: string[] = [];
  if (!config.ytdlpProxyUrl.trim()) {
    issues.push("YTDLP_PROXY_ENABLED=true but YTDLP_PROXY_URL is empty");
  } else if (!parseProxyUrl(config.ytdlpProxyUrl)) {
    issues.push("YTDLP_PROXY_URL is not a valid http/https/socks proxy URL");
  }
  return { ok: issues.length === 0, issues };
}

/** Lightweight connectivity probe via yt-dlp (no media download). */
export async function probeProxyViaYtDlp(smokeUrl?: string): Promise<{ ok: boolean; detail: string }> {
  if (!config.ytdlpProxyEnabled) return { ok: false, detail: "disabled" };
  const validation = validateProxyConfigWhenEnabled();
  if (!validation.ok) return { ok: false, detail: validation.issues[0] ?? "invalid config" };

  const url = smokeUrl?.trim() || "https://www.youtube.com/watch?v=jNQXAC9IVRw";
  const proxyUrl = config.ytdlpProxyUrl.trim();

  return new Promise((resolve) => {
    const child = spawn(
      YT_DLP,
      [
        "--proxy",
        proxyUrl,
        "--skip-download",
        "--print",
        "id",
        "--no-playlist",
        "--no-warnings",
        url,
      ],
      { stdio: ["ignore", "pipe", "pipe"] }
    );
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      resolve({ ok: false, detail: "timeout" });
    }, config.ytdlpProxyTimeoutMs);

    child.stderr?.on("data", (d) => {
      stderr = (stderr + d.toString()).slice(-500);
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({
        ok: false,
        detail: err.message.includes("ENOENT") ? "yt-dlp not found" : "spawn failed",
      });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code === 0) {
        resolve({ ok: true, detail: "yt-dlp proxy probe ok" });
        return;
      }
      const lower = stderr.toLowerCase();
      if (lower.includes("proxy") || lower.includes("tunnel") || lower.includes("407")) {
        resolve({ ok: false, detail: "proxy connection failed" });
        return;
      }
      resolve({ ok: false, detail: `yt-dlp exit ${code ?? "unknown"}` });
    });
  });
}
