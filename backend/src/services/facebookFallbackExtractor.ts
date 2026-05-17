/**
 * Facebook-only fallback when yt-dlp fails with "Cannot parse data".
 * Does NOT call third-party download sites — only fetches Facebook HTML variants and parses embedded JSON.
 */

import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { config } from "../config";
import { logger } from "./logger";
import { looksLikeNetscapeCookiesFileContent } from "./ytdlp";
import type { DownloadFormatKind } from "./ytdlp";

const FB_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36";

const FETCH_TIMEOUT_MS = 45_000;
const DOWNLOAD_TIMEOUT_MS = 600_000;

export type FacebookFallbackMethod =
  | "desktop_html"
  | "mobile_html"
  | "mbasic_html"
  | "comet_json"
  | "regex_fbcdn";

export type FacebookDirectCandidates = {
  sdUrl?: string;
  hdUrl?: string;
  dashManifest?: string;
};

export type FacebookFallbackOk = {
  ok: true;
  method: FacebookFallbackMethod;
  title?: string;
  durationSeconds?: number;
  thumbnailUrl?: string;
  candidates: FacebookDirectCandidates;
};

export type FacebookFallbackFail = {
  ok: false;
  reason: string;
};

export type FacebookFallbackResult = FacebookFallbackOk | FacebookFallbackFail;

function hostOnlyForLog(u: string): string {
  try {
    return new URL(u).hostname;
  } catch {
    return "invalid";
  }
}

/** Hostnames only for CDN URLs we discovered (no path/query logged). */
function logHostsFromUrls(urls: string[]): string[] {
  const hosts = new Set<string>();
  for (const raw of urls) {
    try {
      hosts.add(new URL(raw).hostname);
    } catch {
      /* skip */
    }
  }
  return [...hosts];
}

function decodeEscapes(s: string): string {
  return s
    .replace(/\\\\/g, "\\")
    .replace(/\\\//g, "/")
    .replace(/\\"/g, '"')
    .replace(/\\u0026/g, "&")
    .replace(/\\u003D/g, "=")
    .replace(/\\u002F/gi, "/");
}

function tryParseFlexibleQuoted(html: string, key: string): string | null {
  const re = new RegExp(`"${key}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`, "i");
  const m = html.match(re);
  if (!m?.[1]) return null;
  try {
    return decodeEscapes(m[1]);
  } catch {
    return null;
  }
}

/** Pull https://video…fbcdn…mp4… from escaped or plain HTML. */
function regexFbcdnMp4(html: string): string[] {
  const found = new Set<string>();
  const patterns = [
    /https:\\\/\\\/video[a-z0-9\-_.]*\.fbcdn\.net[^"'\\\s<>]{10,800}/gi,
    /https:\/\/video[a-z0-9\-_.]*\.fbcdn\.net[^\s"'<>]{10,800}/gi,
  ];
  for (const re of patterns) {
    let m: RegExpExecArray | null;
    while ((m = re.exec(html)) !== null) {
      let u = m[0].trim();
      if (u.includes("\\")) u = decodeEscapes(u);
      if (u.startsWith("https://") && /\.mp4/i.test(u)) found.add(u);
    }
  }
  return [...found];
}

function classifySdHd(url: string): "sd" | "hd" | "unknown" {
  const u = url.toLowerCase();
  if (/\bsve_sd\b|tag=sd|[/_]sd[/_]/i.test(u)) return "sd";
  if (/720|1080|high|hd|dash_h264|gen2_720|basic-gen2/i.test(u)) return "hd";
  return "unknown";
}

function assignSdHdFromUrls(urls: string[]): FacebookDirectCandidates {
  const out: FacebookDirectCandidates = {};
  if (!urls.length) return out;
  let hd: string | undefined;
  let sd: string | undefined;
  for (const u of urls) {
    const cls = classifySdHd(u);
    if (cls === "hd") hd = u;
    if (cls === "sd") sd = u;
  }
  if (!hd && !sd && urls.length === 1) {
    out.hdUrl = urls[0];
    return out;
  }
  if (hd) out.hdUrl = hd;
  if (sd) out.sdUrl = sd;
  if (!out.hdUrl && urls.length) out.hdUrl = urls.find((u) => classifySdHd(u) !== "sd") ?? urls[0];
  if (!out.sdUrl && urls.length > 1) out.sdUrl = urls.find((u) => classifySdHd(u) === "sd") ?? urls[urls.length - 1];
  return out;
}

function parseThumbnail(html: string): string | undefined {
  const og = html.match(/property=["']og:image["']\s+content=["']([^"']+)["']/i);
  if (og?.[1]) return decodeEscapes(og[1]);
  const og2 = html.match(/content=["']([^"']+)["']\s+property=["']og:image["']/i);
  if (og2?.[1]) return decodeEscapes(og2[1]);
  const thumb = html.match(/"preferred_thumbnail"\s*:\s*\{[^}]*"image"\s*:\s*\{[^}]*"uri"\s*:\s*"((?:\\.|[^"\\])*)"/i);
  if (thumb?.[1]) return decodeEscapes(thumb[1]);
  return undefined;
}

function parseDurationSeconds(html: string): number | undefined {
  const patterns = [
    /"video_duration"\s*:\s*(\d+)/i,
    /"length_in_second"\s*:\s*(\d+)/i,
    /"duration_ms"\s*:\s*(\d+)/i,
    /Duration:\s*(\d+)\s*minutes?,?\s*(\d+)\s*seconds?/i,
  ];
  for (const re of patterns) {
    const m = html.match(re);
    if (!m) continue;
    if (re.source.includes("minutes")) {
      const min = Number(m[1]);
      const sec = Number(m[2]);
      if (Number.isFinite(min) && Number.isFinite(sec)) return min * 60 + sec;
    } else {
      const n = Number(m[1]);
      if (!Number.isFinite(n)) continue;
      if (re.source.includes("duration_ms")) return Math.round(n / 1000);
      return Math.floor(n);
    }
  }
  return undefined;
}

function parseTitle(html: string): string | undefined {
  const og = html.match(/property=["']og:title["']\s+content=["']([^"']+)["']/i);
  if (og?.[1]) return decodeEscapes(og[1]).slice(0, 500);
  const t = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  if (t?.[1]) return decodeEscapes(t[1]).trim().slice(0, 500);
  return undefined;
}

function readCookieHeaderFromNetscapeFile(absPath: string): string | null {
  let buf: Buffer;
  try {
    buf = fs.readFileSync(absPath);
  } catch {
    return null;
  }
  const text = buf.toString("utf8");
  if (!looksLikeNetscapeCookiesFileContent(text)) return null;

  const pairs: string[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/\s+$/, "");
    if (!line || line.startsWith("#")) continue;
    const p = line.split("\t");
    if (p.length < 7) continue;
    const domain = (p[0] ?? "").trim().toLowerCase();
    if (
      !domain.includes("facebook") &&
      !domain.includes("fbcdn") &&
      !domain.includes("instagram") &&
      domain !== ".facebook.com"
    ) {
      continue;
    }
    const name = p[5];
    const value = p[6];
    if (name && value !== undefined) pairs.push(`${encodeURIComponent(name)}=${encodeURIComponent(value)}`);
  }
  return pairs.length ? pairs.join("; ") : null;
}

/** Uses validated secrets cookies path (read-only file OK — we only read). */
export function tryReadFacebookCookieHeader(): string | null {
  const p = config.cookiesFile?.trim();
  if (!p || !fs.existsSync(p)) return null;
  return readCookieHeaderFromNetscapeFile(p);
}

function watchVariantsFromHtml(html: string, fallbackHost: string): string[] {
  const ids = new Set<string>();
  const re = /["'](?:video_id|videoId|owner_id)["']\s*:\s*"?(\d{8,20})"?/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) !== null) ids.add(m[1]!);
  const re2 = /\/videos\/(\d{8,20})\b/gi;
  while ((m = re2.exec(html)) !== null) ids.add(m[1]!);
  const re3 = /[?&]v=(\d{8,20})\b/gi;
  while ((m = re3.exec(html)) !== null) ids.add(m[1]!);

  const urls: string[] = [];
  const host = fallbackHost.includes("facebook") ? fallbackHost : "www.facebook.com";
  for (const id of ids) {
    urls.push(`https://${host}/watch/?v=${id}`);
    urls.push(`https://m.facebook.com/watch/?v=${id}`);
    urls.push(`https://mbasic.facebook.com/watch/?v=${id}`);
  }
  return [...new Set(urls)];
}

function buildPageVariants(canonicalUrl: string): { variant: FacebookFallbackMethod; url: string }[] {
  const u = new URL(canonicalUrl);
  const list: { variant: FacebookFallbackMethod; url: string }[] = [];

  list.push({ variant: "desktop_html", url: canonicalUrl });

  if (u.hostname === "www.facebook.com" || u.hostname === "facebook.com") {
    list.push({
      variant: "mobile_html",
      url: canonicalUrl.replace(/:\/\/(www\.)?facebook\.com/i, "://m.facebook.com"),
    });
  }

  const vParam = u.searchParams.get("v");
  if (vParam) {
    list.push({ variant: "mbasic_html", url: `https://mbasic.facebook.com/watch/?v=${encodeURIComponent(vParam)}` });
  }

  const seen = new Set<string>();
  return list.filter((x) => {
    if (seen.has(x.url)) return false;
    seen.add(x.url);
    return true;
  });
}

async function fetchHtml(url: string, cookieHeader: string | null, variant: FacebookFallbackMethod): Promise<string | null> {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), FETCH_TIMEOUT_MS);
  try {
    const headers: Record<string, string> = {
      "User-Agent": FB_UA,
      Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.9",
      Referer: "https://www.facebook.com/",
      "Sec-Fetch-Dest": "document",
      "Sec-Fetch-Mode": "navigate",
    };
    if (cookieHeader) headers.Cookie = cookieHeader;

    logger.info({ facebook_fallback_page_fetch: true, variant, urlHost: hostOnlyForLog(url) }, "facebook_fallback_page_fetch");

    const res = await fetch(url, { redirect: "follow", headers, signal: ac.signal });
    if (!res.ok) return null;
    return await res.text();
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

function extractFromHtml(html: string, _method: FacebookFallbackMethod): FacebookDirectCandidates {
  const keys = [
    "browser_native_hd_url",
    "browser_native_sd_url",
    "playable_url_quality_hd",
    "playable_url",
    "playable_url_quality_sd",
  ] as const;

  const urls: string[] = [];
  for (const key of keys) {
    const v = tryParseFlexibleQuoted(html, key);
    if (v?.startsWith("https://") && /\.mp4/i.test(v)) urls.push(v);
    if (v?.includes("fbcdn") && /\.mp4/i.test(v)) urls.push(v);
  }

  for (const u of regexFbcdnMp4(html)) urls.push(u);

  const uniq = [...new Set(urls)];
  const merged = assignSdHdFromUrls(uniq);
  const dash = tryParseFlexibleQuoted(html, "dash_manifest");
  if (dash?.startsWith("https://")) merged.dashManifest = dash;
  return merged;
}

/**
 * Full extraction: tries desktop/mobile/mbasic (+ watch URLs discovered in HTML).
 */
export async function extractFacebookDirectMedia(canonicalUrl: string): Promise<FacebookFallbackResult> {
  const urlHost = hostOnlyForLog(canonicalUrl);
  logger.info({ facebook_fallback_start: true, urlHost }, "facebook_fallback_start");

  const cookieHeader = tryReadFacebookCookieHeader();

  const tried = new Set<string>();
  const variants = buildPageVariants(canonicalUrl);

  let lastCandidates: FacebookDirectCandidates = {};
  let lastMethod: FacebookFallbackMethod = "desktop_html";
  let lastHtml = "";

  const attempt = async (variant: FacebookFallbackMethod, url: string): Promise<boolean> => {
    if (tried.has(url)) return false;
    tried.add(url);
    const html = await fetchHtml(url, cookieHeader, variant);
    if (!html || html.length < 500) return false;
    lastHtml = html;
    lastMethod = variant;
    const c = extractFromHtml(html, variant);
    lastCandidates = c;
    const mp4s = [c.hdUrl, c.sdUrl].filter(Boolean) as string[];
    const count = mp4s.length + (c.dashManifest ? 1 : 0);
    logger.info(
      {
        facebook_fallback_candidates_found: count,
        variant,
        urlHost: hostOnlyForLog(url),
        candidateHosts: logHostsFromUrls(mp4s),
      },
      "facebook_fallback_candidates_found"
    );
    return mp4s.length > 0;
  };

  for (const { variant, url } of variants) {
    if (await attempt(variant, url)) break;
  }

  if (!lastCandidates.hdUrl && !lastCandidates.sdUrl && lastHtml) {
    const extraUrls = watchVariantsFromHtml(lastHtml, new URL(canonicalUrl).hostname.replace(/^m\./, "www."));
    for (const u of extraUrls.slice(0, 6)) {
      if (await attempt("mbasic_html", u)) break;
    }
  }

  const hd = lastCandidates.hdUrl;
  const sd = lastCandidates.sdUrl;

  if (!hd && !sd) {
    logger.warn({ facebook_fallback_failed: true, reason: "no_mp4_candidates", urlHost }, "facebook_fallback_failed");
    return { ok: false, reason: "no_mp4_candidates" };
  }

  const thumbnailUrl = parseThumbnail(lastHtml);
  const durationSeconds = parseDurationSeconds(lastHtml);
  let title = parseTitle(lastHtml);
  if (!title || /^facebook$/i.test(title)) title = "Facebook video";

  logger.info(
    {
      facebook_fallback_success: true,
      method: lastMethod,
      urlHost,
      candidateHosts: logHostsFromUrls([hd, sd].filter(Boolean) as string[]),
      durationSeconds,
      hasThumb: Boolean(thumbnailUrl),
    },
    "facebook_fallback_success"
  );

  return {
    ok: true,
    method: lastMethod,
    title,
    durationSeconds,
    thumbnailUrl,
    candidates: { hdUrl: hd, sdUrl: sd, dashManifest: lastCandidates.dashManifest },
  };
}

export function pickFacebookMp4UrlForFormat(
  format: DownloadFormatKind,
  c: FacebookDirectCandidates
): string | null {
  const hd = c.hdUrl;
  const sd = c.sdUrl;
  switch (format) {
    case "audio_mp3":
      return null;
    case "480p":
      return sd ?? hd ?? null;
    case "1080p":
    case "720p":
    case "tiktok_ready":
    case "best":
      return hd ?? sd ?? null;
    default:
      return hd ?? sd ?? null;
  }
}

export async function downloadFacebookMp4ToFile(mp4Url: string, destFsPath: string): Promise<{ bytes: bigint }> {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), DOWNLOAD_TIMEOUT_MS);
  try {
    const res = await fetch(mp4Url, {
      redirect: "follow",
      signal: ac.signal,
      headers: {
        "User-Agent": FB_UA,
        Accept: "*/*",
        Referer: "https://www.facebook.com/",
        Origin: "https://www.facebook.com",
      },
    });
    if (!res.ok) throw new Error(`http_${res.status}`);
    const partial = `${destFsPath}.part`;
    await fsp.mkdir(path.dirname(destFsPath), { recursive: true });
    const ws = fs.createWriteStream(partial);
    if (!res.body) throw new Error("empty_body");
    await pipeline(Readable.fromWeb(res.body as import("stream/web").ReadableStream), ws);
    const st = await fsp.stat(partial);
    if (st.size <= 0) {
      await fsp.unlink(partial).catch(() => {});
      throw new Error("empty_file");
    }
    await fsp.rename(partial, destFsPath);
    return { bytes: BigInt(st.size) };
  } finally {
    clearTimeout(t);
  }
}
