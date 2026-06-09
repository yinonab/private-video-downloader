import fs from "node:fs";
import path from "node:path";

export const DEFAULT_SMOKE_URL = "https://www.youtube.com/watch?v=jNQXAC9IVRw";
export const DEFAULT_LIST_CAP = 5;

export type YoutubeDiagClassification =
  | "success"
  | "auth_required"
  | "geo_restricted"
  | "no_formats_found"
  | "format_unavailable"
  | "network_or_proxy"
  | "unknown";

export function truthyEnv(name: string): boolean {
  const v = process.env[name]?.trim().toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

export function parseUrlList(raw: string): string[] {
  return raw
    .split(/[\r\n,]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("#"));
}

export function readUrlsFromFile(filePath: string, backendRoot: string): string[] {
  const resolved = path.isAbsolute(filePath) ? filePath : path.join(backendRoot, filePath);
  if (!fs.existsSync(resolved)) {
    console.error(`YOUTUBE_DIAG_URLS_FILE not found: ${resolved}`);
    process.exit(1);
  }
  return parseUrlList(fs.readFileSync(resolved, "utf8"));
}

export function resolveYoutubeDiagUrls(backendRoot: string): { urls: string[]; usedDefaultSmoke: boolean } {
  const fromEnv = process.env.YOUTUBE_DIAG_URLS?.trim()
    ? parseUrlList(process.env.YOUTUBE_DIAG_URLS)
    : [];
  const fromFile = process.env.YOUTUBE_DIAG_URLS_FILE?.trim()
    ? readUrlsFromFile(process.env.YOUTUBE_DIAG_URLS_FILE.trim(), backendRoot)
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

export function resolveYoutubeDiagDelayMs(urlCount: number): number {
  const raw = process.env.YOUTUBE_DIAG_DELAY_MS?.trim();
  if (raw) return Math.max(0, parseInt(raw, 10) || 0);
  return urlCount > 1 ? 2000 : 0;
}

export function safeHost(urlString: string): string {
  try {
    return new URL(urlString).hostname.toLowerCase();
  } catch {
    return "invalid";
  }
}

export function safeYouTubeVideoId(urlString: string): string {
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

export function redactSensitiveDiagText(text: string): string {
  let s = text;
  s = s.replace(/\b(?:PO Token|po_token|visitor_data|potoken)[^\s]*/gi, "[REDACTED_TOKEN]");
  s = s.replace(/https?:\/\/[^\s:@]+:[^\s@]+@[^\s]+/gi, "[REDACTED_PROXY_URL]");
  s = s.replace(/(proxy(?:\s*url)?\s*[=:]\s*)\S+/gi, "$1[REDACTED]");
  s = s.replace(/(--cookies(?:-from-browser)?\s+)\S+/gi, "$1[REDACTED_PATH]");
  s = s.replace(/^[^\t]+\tTRUE\t[^\t]+\t(TRUE|FALSE)\t\d+\t[^\t]+\t[^\r\n]+$/gm, "[REDACTED_COOKIE_ROW]");
  s = s.replace(/(#(?:HttpOnly_)?[^\s]+\s+)[^\s]+(\s+[^\r\n]+)/g, "$1[REDACTED]$2");
  s = s.replace(/base_url=http[^\s;"]+/gi, "base_url=[REDACTED_PROVIDER_URL]");
  return s;
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function printCompactTable(header: string[], rows: string[][]): void {
  const widths = header.map((h) => h.length);
  for (const row of rows) {
    row.forEach((cell, ci) => {
      widths[ci] = Math.max(widths[ci]!, cell.length);
    });
  }
  const fmt = (row: string[]) => row.map((cell, ci) => cell.padEnd(widths[ci]!)).join("  ");
  console.info(fmt(header));
  console.info(widths.map((w) => "-".repeat(w)).join("  "));
  for (const row of rows) {
    console.info(fmt(row));
  }
}

export function summarizeClassifications(
  rows: { outcome: string; classification: YoutubeDiagClassification }[]
): Record<string, number> {
  const counts: Record<string, number> = {
    success: 0,
    auth_required: 0,
    geo_restricted: 0,
    no_formats_found: 0,
    format_unavailable: 0,
    network_or_proxy: 0,
    unknown: 0,
  };
  for (const r of rows) {
    if (r.outcome === "success") {
      counts.success!++;
    } else {
      counts[r.classification] = (counts[r.classification] ?? 0) + 1;
    }
  }
  return counts;
}
