import { spawnSync } from "node:child_process";
import { config } from "../config";
import { hostnameIsYouTube } from "./urlSafety";

export type YtdlpPoTokenContext = {
  operation: "analyze" | "download";
  urlHost: string;
  platform?: string;
  isYouTube: boolean;
  attempt?: number;
  requestedFormat?: string;
  requestedQuality?: string;
};

export type YtdlpPoTokenOperationalFlags = {
  poTokenEnabled: boolean;
  poTokenUsed: boolean;
  poTokenClient: string;
  providerConfigured: boolean;
  providerMode: string;
};

const DEFAULT_PROVIDER_URL = "http://127.0.0.1:4416";

/** Safe operational flags for logs/diagnostics — never includes token values. */
export function ytDlpPoTokenOperationalFlags(context?: Pick<YtdlpPoTokenContext, "isYouTube">): YtdlpPoTokenOperationalFlags {
  const enabled = config.ytdlpPoTokenEnabled;
  const isYouTube = context?.isYouTube ?? false;
  const providerConfigured = Boolean(resolveProviderBaseUrl());
  return {
    poTokenEnabled: enabled,
    poTokenUsed: enabled && isYouTube,
    poTokenClient: config.ytdlpPoTokenClient,
    providerConfigured,
    providerMode: config.ytdlpPoTokenMode,
  };
}

export function resolveProviderBaseUrl(): string | undefined {
  if (!config.ytdlpPoTokenEnabled) return undefined;
  if (config.ytdlpPoTokenMode !== "server") return undefined;
  const raw = config.ytdlpPoTokenProviderUrl.trim();
  return raw || DEFAULT_PROVIDER_URL;
}

/**
 * Append YouTube PO Token Provider extractor args when enabled.
 * No-op when disabled or non-YouTube — preserves cookies-only behavior.
 */
export function withYtDlpPoTokenArgs(args: string[], context: YtdlpPoTokenContext): string[] {
  if (!config.ytdlpPoTokenEnabled || !context.isYouTube) {
    return [...args];
  }

  const inserts: string[] = [];
  const client = config.ytdlpPoTokenClient.trim();
  if (client) {
    inserts.push("--extractor-args", `youtube:player_client=${client}`);
  }

  if (config.ytdlpPoTokenMode === "server") {
    const baseUrl = resolveProviderBaseUrl();
    if (baseUrl) {
      inserts.push("--extractor-args", `youtubepot-bgutilhttp:base_url=${baseUrl}`);
    }
  } else if (config.ytdlpPoTokenMode === "script") {
    const scriptHome = config.ytdlpPoTokenScriptHome.trim();
    if (scriptHome) {
      inserts.push("--extractor-args", `youtubepot-bgutilscript:server_home=${scriptHome}`);
    }
  }

  if (inserts.length === 0) return [...args];

  const result = [...args];
  const jsIdx = result.indexOf("--js-runtimes");
  const insertAt = jsIdx >= 0 ? jsIdx + 2 : 0;
  result.splice(insertAt, 0, ...inserts);
  return result;
}

export function ytdlpPoTokenContextFromUrl(
  url: string,
  operation: "analyze" | "download",
  extra?: Omit<YtdlpPoTokenContext, "operation" | "urlHost" | "isYouTube">
): YtdlpPoTokenContext {
  let urlHost = "unknown";
  try {
    urlHost = new URL(url).hostname.toLowerCase();
  } catch {
    /* ignore */
  }
  return {
    operation,
    urlHost,
    isYouTube: hostnameIsYouTube(urlHost),
    ...extra,
  };
}

/** pip-installed bgutil-ytdlp-pot-provider plugin presence (no YouTube HTTP). */
export function detectBgutilPotPluginInstalled(): { installed: boolean; detail: string } {
  const r = spawnSync("python3", ["-m", "pip", "show", "bgutil-ytdlp-pot-provider"], {
    encoding: "utf8",
    timeout: 15_000,
  });
  if (r.error) {
    const msg = r.error.message;
    return {
      installed: false,
      detail: msg.includes("ENOENT") ? "python3 not found" : msg,
    };
  }
  if (r.status !== 0) {
    return { installed: false, detail: "package not installed" };
  }
  const versionLine = (r.stdout || "").split(/\r?\n/).find((l) => l.startsWith("Version:"));
  return { installed: true, detail: versionLine?.trim() || "installed" };
}

/** HTTP reachability probe for bgutil server mode (no response body logged). */
export async function probePotProviderReachable(baseUrl?: string): Promise<{ ok: boolean; detail: string }> {
  const url = (baseUrl ?? resolveProviderBaseUrl())?.trim();
  if (!url) {
    return { ok: false, detail: "provider URL not configured" };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.ytdlpPoTokenTimeoutMs);
  try {
    const res = await fetch(url.replace(/\/+$/, "") + "/", {
      method: "GET",
      signal: controller.signal,
    });
    return { ok: res.ok || res.status < 500, detail: `HTTP ${res.status}` };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.includes("abort")) return { ok: false, detail: "timeout" };
    return { ok: false, detail: msg.includes("ECONNREFUSED") ? "connection refused" : "unreachable" };
  } finally {
    clearTimeout(timer);
  }
}

export function validatePoTokenConfigWhenEnabled(): { ok: boolean; issues: string[] } {
  if (!config.ytdlpPoTokenEnabled) {
    return { ok: true, issues: [] };
  }

  const issues: string[] = [];
  const plugin = detectBgutilPotPluginInstalled();
  if (!plugin.installed) {
    issues.push(`bgutil-ytdlp-pot-provider plugin missing (${plugin.detail})`);
  }

  if (config.ytdlpPoTokenMode === "server") {
    if (!resolveProviderBaseUrl()) {
      issues.push("server mode requires YTDLP_PO_TOKEN_PROVIDER_URL or default localhost:4416");
    }
  } else if (config.ytdlpPoTokenMode === "script") {
    if (!config.ytdlpPoTokenScriptHome.trim()) {
      issues.push("script mode requires YTDLP_PO_TOKEN_SCRIPT_HOME");
    }
  } else {
    issues.push(`unknown YTDLP_PO_TOKEN_MODE: ${config.ytdlpPoTokenMode}`);
  }

  return { ok: issues.length === 0, issues };
}
