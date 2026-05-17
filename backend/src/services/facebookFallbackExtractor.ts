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

/** Desktop Chrome — avoids Facebook WebLite / unsupported-interstitial responses seen with mobile UA. */
export const FACEBOOK_DESKTOP_CHROME_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";

/** Android Chrome mobile — not iPhone/WebLite profile. */
const FACEBOOK_MOBILE_WEB_UA =
  "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36";

const FETCH_TIMEOUT_MS = 45_000;
const DOWNLOAD_TIMEOUT_MS = 600_000;

/** High-level fetch persona (headers + UA). */
export type FacebookFetchProfile = "desktop_chrome" | "mobile_web" | "mbasic_client";

export type FacebookFallbackMethod =
  | "desktop_chrome"
  | "mobile_web"
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
  /** Fetch profile used for the successful attempt (mirrors method for chrome/mobile/mbasic). */
  profile: FacebookFetchProfile;
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

export type FacebookHtmlSignalCounts = {
  dot_mp4: number;
  dash_manifest: number;
  videoDeliveryLegacyFields: number;
  playable_url: number;
  playable_url_quality_hd: number;
  browser_native_sd_url: number;
  browser_native_hd_url: number;
  unsupported_interstitial: number;
  weblite_unsupported: number;
  browser_unsupported: number;
};

export type FacebookDiagStep = {
  profile: FacebookFetchProfile;
  method: FacebookFallbackMethod;
  requestUrlHost: string;
  requestUrlPathLen: number;
  finalUrlHost: string;
  finalUrlPathLen: number;
  htmlChars: number;
  counts: FacebookHtmlSignalCounts;
  extractedSd: boolean;
  extractedHd: boolean;
  candidateHosts: string[];
};

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

function methodToProfile(method: FacebookFallbackMethod): FacebookFetchProfile {
  switch (method) {
    case "desktop_chrome":
      return "desktop_chrome";
    case "mobile_web":
      return "mobile_web";
    case "mbasic_html":
      return "mbasic_client";
    default:
      return "desktop_chrome";
  }
}

function decodeEscapes(s: string): string {
  let out = s
    .replace(/\\\\/g, "\\")
    .replace(/\\\//g, "/")
    .replace(/\\"/g, '"')
    .replace(/\\u0026/g, "&")
    .replace(/\\u003D/g, "=")
    .replace(/\\u003a/gi, ":")
    .replace(/\\u002F/gi, "/");
  out = out.replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
  return out;
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

/** Occurrence counts for diagnostics / sanity checks (no URL logging). */
export function countFacebookHtmlSignals(html: string): FacebookHtmlSignalCounts {
  const lc = html;
  const countInsensitive = (needle: string): number => {
    if (!needle) return 0;
    let n = 0;
    let p = 0;
    const lower = lc.toLowerCase();
    const nl = needle.toLowerCase();
    while (true) {
      const i = lower.indexOf(nl, p);
      if (i === -1) break;
      n++;
      p = i + nl.length;
    }
    return n;
  };

  return {
    dot_mp4: countInsensitive(".mp4"),
    dash_manifest: countInsensitive("dash_manifest"),
    videoDeliveryLegacyFields: countInsensitive("videoDeliveryLegacyFields"),
    playable_url: countInsensitive("playable_url"),
    playable_url_quality_hd: countInsensitive("playable_url_quality_hd"),
    browser_native_sd_url: countInsensitive("browser_native_sd_url"),
    browser_native_hd_url: countInsensitive("browser_native_hd_url"),
    unsupported_interstitial: countInsensitive("unsupported-interstitial"),
    weblite_unsupported: countInsensitive("weblite_unsupported"),
    browser_unsupported: countInsensitive("BROWSER_UNSUPPORTED"),
  };
}

function mp4LikeUrl(v: string | null | undefined): v is string {
  return typeof v === "string" && v.startsWith("https://") && /\.mp4/i.test(v);
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

export function videoIdFromFacebookUrl(urlString: string): string | null {
  try {
    const url = new URL(urlString);
    const v = url.searchParams.get("v");
    if (v && /^\d{8,20}$/.test(v)) return v;
    const m = url.pathname.match(/\/videos\/(\d{8,20})\b/i);
    return m?.[1] ?? null;
  } catch {
    return null;
  }
}

function toWwwFacebookUrl(urlString: string): string | null {
  try {
    const u = new URL(urlString);
    if (u.hostname === "m.facebook.com" || u.hostname === "mbasic.facebook.com") {
      u.hostname = "www.facebook.com";
      return u.toString();
    }
    if (u.hostname === "facebook.com") {
      u.hostname = "www.facebook.com";
      return u.toString();
    }
    return urlString;
  } catch {
    return null;
  }
}

function toMobileFacebookUrl(urlString: string): string | null {
  try {
    const u = new URL(urlString);
    if (u.hostname === "www.facebook.com" || u.hostname === "facebook.com") {
      u.hostname = "m.facebook.com";
      return u.toString();
    }
    return urlString;
  } catch {
    return null;
  }
}

function facebookHostnameKey(hostname: string): string {
  const h = hostname.toLowerCase();
  return h.replace(/^www\./, "");
}

/** Same document as initial desktop probe after redirects (paths normalized, www-aligned). */
function sameDocumentUrl(requestUrl: string, probeFinalUrl: string): boolean {
  const wa = toWwwFacebookUrl(requestUrl) ?? requestUrl;
  const wb = toWwwFacebookUrl(probeFinalUrl) ?? probeFinalUrl;
  try {
    const ua = new URL(wa);
    const ub = new URL(wb);
    const pa = ua.pathname.replace(/\/+$/, "") || "/";
    const pb = ub.pathname.replace(/\/+$/, "") || "/";
    return facebookHostnameKey(ua.hostname) === facebookHostnameKey(ub.hostname) && pa === pb && ua.search === ub.search;
  } catch {
    return false;
  }
}

function urlPathLen(u: string): number {
  try {
    return new URL(u).pathname.length;
  } catch {
    return 0;
  }
}

function dedupeUrls(urls: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const u of urls) {
    try {
      const k = new URL(u).href;
      if (seen.has(k)) continue;
      seen.add(k);
      out.push(u);
    } catch {
      if (!seen.has(u)) {
        seen.add(u);
        out.push(u);
      }
    }
  }
  return out;
}

/**
 * Build ordered fetch attempts: desktop Chrome first (watch + canonical paths), then mobile web, then mbasic.
 * Does not hardcode user ids — uses whatever URLs redirect/normalize to.
 */
export function buildFacebookFetchAttempts(originalUrl: string, redirectFinalUrl: string): { method: FacebookFallbackMethod; url: string }[] {
  const wwwOriginal = toWwwFacebookUrl(originalUrl) ?? originalUrl;
  const wwwFinal = toWwwFacebookUrl(redirectFinalUrl) ?? redirectFinalUrl;

  const baseUrls = dedupeUrls([wwwFinal, wwwOriginal]);

  const list: { method: FacebookFallbackMethod; url: string }[] = [];

  for (const u of baseUrls) {
    list.push({ method: "desktop_chrome", url: u });
  }

  for (const u of baseUrls) {
    const mob = toMobileFacebookUrl(u);
    if (mob) list.push({ method: "mobile_web", url: mob });
  }

  const mbasicSeen = new Set<string>();
  for (const u of baseUrls) {
    const vid = videoIdFromFacebookUrl(u);
    if (!vid) continue;
    const mb = `https://mbasic.facebook.com/watch/?v=${encodeURIComponent(vid)}`;
    if (mbasicSeen.has(mb)) continue;
    mbasicSeen.add(mb);
    list.push({ method: "mbasic_html", url: mb });
  }

  const seen = new Set<string>();
  return list.filter((x) => {
    const k = `${x.method}\n${x.url}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

function headersForProfile(method: FacebookFallbackMethod): Record<string, string> {
  if (method === "desktop_chrome") {
    return {
      "User-Agent": FACEBOOK_DESKTOP_CHROME_UA,
      Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.9",
      "Accept-Encoding": "gzip, deflate, br",
      "Upgrade-Insecure-Requests": "1",
      "Sec-Fetch-Site": "none",
      "Sec-Fetch-Mode": "navigate",
      "Sec-Fetch-User": "?1",
      "Sec-Fetch-Dest": "document",
    };
  }
  if (method === "mobile_web") {
    return {
      "User-Agent": FACEBOOK_MOBILE_WEB_UA,
      Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.9",
      "Accept-Encoding": "gzip, deflate, br",
      "Upgrade-Insecure-Requests": "1",
      "Sec-Fetch-Site": "none",
      "Sec-Fetch-Mode": "navigate",
      "Sec-Fetch-User": "?1",
      "Sec-Fetch-Dest": "document",
    };
  }
  /* mbasic_html — minimal desktop-like */
  return {
    "User-Agent": FACEBOOK_DESKTOP_CHROME_UA,
    Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    Referer: "https://www.facebook.com/",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Upgrade-Insecure-Requests": "1",
  };
}

export type FacebookFetchPageResult =
  | { ok: true; html: string; finalUrl: string; status: number }
  | { ok: false; status: number; finalUrl: string };

/** Low-level fetch for diagnostics and redirect discovery. */
export async function fetchFacebookPage(
  url: string,
  cookieHeader: string | null,
  method: FacebookFallbackMethod
): Promise<FacebookFetchPageResult> {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), FETCH_TIMEOUT_MS);
  try {
    const headers: Record<string, string> = { ...headersForProfile(method) };
    if (cookieHeader) headers.Cookie = cookieHeader;
    if (method === "desktop_chrome" || method === "mobile_web") {
      headers.Referer = "https://www.facebook.com/";
    }

    logger.info(
      {
        facebook_fallback_page_fetch: true,
        profile: methodToProfile(method),
        variant: method,
        urlHost: hostOnlyForLog(url),
      },
      "facebook_fallback_page_fetch"
    );

    const res = await fetch(url, { redirect: "follow", headers, signal: ac.signal });
    const finalUrl = res.url || url;
    if (!res.ok) return { ok: false, status: res.status, finalUrl };
    const html = await res.text();
    return { ok: true, html, finalUrl, status: res.status };
  } catch {
    return { ok: false, status: 0, finalUrl: url };
  } finally {
    clearTimeout(t);
  }
}

function extractUrlsFromVideoDeliveryLegacy(html: string): string[] {
  const marker = "videoDeliveryLegacyFields";
  const idx = html.indexOf(marker);
  if (idx === -1) return [];
  const chunk = html.slice(idx, Math.min(idx + 900_000, html.length));
  const keys = [
    "browser_native_hd_url",
    "browser_native_sd_url",
    "playable_url_quality_hd",
    "playable_url",
    "playable_url_quality_sd",
  ] as const;
  const urls: string[] = [];
  for (const key of keys) {
    const v = tryParseFlexibleQuoted(chunk, key);
    if (mp4LikeUrl(v)) urls.push(v);
  }
  urls.push(...regexFbcdnMp4(chunk));
  return urls;
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
    if (mp4LikeUrl(v)) urls.push(v);
  }

  urls.push(...regexFbcdnMp4(html));
  urls.push(...extractUrlsFromVideoDeliveryLegacy(html));

  const uniq = [...new Set(urls)];
  const merged = assignSdHdFromUrls(uniq);
  const dash = tryParseFlexibleQuoted(html, "dash_manifest");
  if (!dash) {
    const idx = html.indexOf("videoDeliveryLegacyFields");
    if (idx !== -1) {
      const chunk = html.slice(idx, Math.min(idx + 900_000, html.length));
      const dash2 = tryParseFlexibleQuoted(chunk, "dash_manifest");
      if (dash2?.startsWith("https://")) merged.dashManifest = dash2;
    }
  } else if (dash.startsWith("https://")) {
    merged.dashManifest = dash;
  }
  return merged;
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
  const host = fallbackHost.includes("facebook") ? fallbackHost.replace(/^m\./, "www.") : "www.facebook.com";
  for (const id of ids) {
    urls.push(`https://${host}/watch/?v=${id}`);
    urls.push(`https://www.facebook.com/watch/?v=${id}`);
  }
  return dedupeUrls(urls);
}

function candidatesHaveMp4(c: FacebookDirectCandidates): boolean {
  return Boolean(c.hdUrl || c.sdUrl);
}

async function facebookFallbackExtractInner(
  canonicalUrl: string,
  cookieHeader: string | null,
  collectDiag: boolean
): Promise<{
  result: FacebookFallbackResult;
  redirectProbe?: { finalUrlHost: string; finalPathLen: number; counts: FacebookHtmlSignalCounts; htmlChars: number };
  steps?: FacebookDiagStep[];
}> {
  const urlHost = hostOnlyForLog(canonicalUrl);
  const steps: FacebookDiagStep[] | undefined = collectDiag ? [] : undefined;

  const appendStep = (
    method: FacebookFallbackMethod,
    requestUrl: string,
    finalUrl: string,
    html: string | null,
    c: FacebookDirectCandidates | null
  ): void => {
    if (!steps) return;
    const counts = html && html.length > 0 ? countFacebookHtmlSignals(html) : countFacebookHtmlSignals("");
    steps.push({
      profile: methodToProfile(method),
      method,
      requestUrlHost: hostOnlyForLog(requestUrl),
      requestUrlPathLen: urlPathLen(requestUrl),
      finalUrlHost: hostOnlyForLog(finalUrl),
      finalUrlPathLen: urlPathLen(finalUrl),
      htmlChars: html?.length ?? 0,
      counts,
      extractedSd: Boolean(c?.sdUrl),
      extractedHd: Boolean(c?.hdUrl),
      candidateHosts: logHostsFromUrls([c?.sdUrl, c?.hdUrl].filter(Boolean) as string[]),
    });
  };

  const probe = await fetchFacebookPage(canonicalUrl, cookieHeader, "desktop_chrome");
  const redirectProbe = {
    finalUrlHost: hostOnlyForLog(probe.finalUrl),
    finalPathLen: urlPathLen(probe.finalUrl),
    counts: probe.ok ? countFacebookHtmlSignals(probe.html) : countFacebookHtmlSignals(""),
    htmlChars: probe.ok ? probe.html.length : 0,
  };

  const resolvedFinal = probe.ok ? probe.finalUrl : canonicalUrl;
  const attempts = buildFacebookFetchAttempts(canonicalUrl, resolvedFinal);

  let lastCandidates: FacebookDirectCandidates = {};
  let lastMethod: FacebookFallbackMethod = "desktop_chrome";
  let lastProfile: FacebookFetchProfile = "desktop_chrome";
  let lastHtml = "";

  const tried = new Set<string>();

  const attempt = async (method: FacebookFallbackMethod, url: string): Promise<boolean> => {
    const key = `${method}\t${url}`;
    if (tried.has(key)) return false;
    tried.add(key);

    let html: string | null = null;
    let finalUrl = url;

    if (method === "desktop_chrome" && probe.ok && sameDocumentUrl(url, probe.finalUrl)) {
      html = probe.html;
      finalUrl = probe.finalUrl;
    } else {
      const fr = await fetchFacebookPage(url, cookieHeader, method);
      finalUrl = fr.finalUrl;
      if (!fr.ok || fr.html.length < 500) {
        appendStep(method, url, finalUrl, fr.ok ? fr.html : null, fr.ok ? extractFromHtml(fr.html, method) : null);
        return false;
      }
      html = fr.html;
    }

    if (!html || html.length < 500) {
      appendStep(method, url, finalUrl, html, null);
      return false;
    }

    lastHtml = html;
    lastMethod = method;
    lastProfile = methodToProfile(method);
    const c = extractFromHtml(html, method);
    lastCandidates = c;
    appendStep(method, url, finalUrl, html, c);

    const mp4s = [c.hdUrl, c.sdUrl].filter(Boolean) as string[];
    const count = mp4s.length + (c.dashManifest ? 1 : 0);
    logger.info(
      {
        facebook_fallback_candidates_found: count,
        variant: method,
        profile: lastProfile,
        urlHost: hostOnlyForLog(url),
        candidateHosts: logHostsFromUrls(mp4s),
        foundSd: Boolean(c.sdUrl),
        foundHd: Boolean(c.hdUrl),
      },
      "facebook_fallback_candidates_found"
    );
    return mp4s.length > 0;
  };

  for (const { method, url } of attempts) {
    if (await attempt(method, url)) {
      const hd = lastCandidates.hdUrl;
      const sd = lastCandidates.sdUrl;
      const thumbnailUrl = parseThumbnail(lastHtml);
      const durationSeconds = parseDurationSeconds(lastHtml);
      let title = parseTitle(lastHtml);
      if (!title || /^facebook$/i.test(title)) title = "Facebook video";
      logger.info(
        {
          facebook_fallback_success: true,
          method: lastMethod,
          profile: lastProfile,
          urlHost,
          candidateHosts: logHostsFromUrls([hd, sd].filter(Boolean) as string[]),
          durationSeconds,
          hasThumb: Boolean(thumbnailUrl),
          foundSd: Boolean(sd),
          foundHd: Boolean(hd),
        },
        "facebook_fallback_success"
      );
      const ok: FacebookFallbackOk = {
        ok: true,
        method: lastMethod,
        profile: lastProfile,
        title,
        durationSeconds,
        thumbnailUrl,
        candidates: { hdUrl: hd, sdUrl: sd, dashManifest: lastCandidates.dashManifest },
      };
      return collectDiag ? { result: ok, redirectProbe, steps } : { result: ok };
    }
  }

  if (!candidatesHaveMp4(lastCandidates) && lastHtml) {
    let host: string;
    try {
      host = new URL(toWwwFacebookUrl(canonicalUrl) ?? canonicalUrl).hostname.replace(/^m\./, "www.");
    } catch {
      host = "www.facebook.com";
    }
    const extraUrls = watchVariantsFromHtml(lastHtml, host);
    for (const u of extraUrls.slice(0, 10)) {
      if (await attempt("desktop_chrome", u)) {
        const hd = lastCandidates.hdUrl;
        const sd = lastCandidates.sdUrl;
        const thumbnailUrl = parseThumbnail(lastHtml);
        const durationSeconds = parseDurationSeconds(lastHtml);
        let title = parseTitle(lastHtml);
        if (!title || /^facebook$/i.test(title)) title = "Facebook video";
        logger.info(
          {
            facebook_fallback_success: true,
            method: lastMethod,
            profile: lastProfile,
            urlHost,
            candidateHosts: logHostsFromUrls([hd, sd].filter(Boolean) as string[]),
            durationSeconds,
            hasThumb: Boolean(thumbnailUrl),
            foundSd: Boolean(sd),
            foundHd: Boolean(hd),
          },
          "facebook_fallback_success"
        );
        const ok: FacebookFallbackOk = {
          ok: true,
          method: lastMethod,
          profile: lastProfile,
          title,
          durationSeconds,
          thumbnailUrl,
          candidates: { hdUrl: hd, sdUrl: sd, dashManifest: lastCandidates.dashManifest },
        };
        return collectDiag ? { result: ok, redirectProbe, steps } : { result: ok };
      }
    }
    if (!candidatesHaveMp4(lastCandidates)) {
      for (const u of extraUrls.slice(0, 10)) {
        const mob = toMobileFacebookUrl(u);
        if (mob && (await attempt("mobile_web", mob))) {
          const hd = lastCandidates.hdUrl;
          const sd = lastCandidates.sdUrl;
          const thumbnailUrl = parseThumbnail(lastHtml);
          const durationSeconds = parseDurationSeconds(lastHtml);
          let title = parseTitle(lastHtml);
          if (!title || /^facebook$/i.test(title)) title = "Facebook video";
          logger.info(
            {
              facebook_fallback_success: true,
              method: lastMethod,
              profile: lastProfile,
              urlHost,
              candidateHosts: logHostsFromUrls([hd, sd].filter(Boolean) as string[]),
              durationSeconds,
              hasThumb: Boolean(thumbnailUrl),
              foundSd: Boolean(sd),
              foundHd: Boolean(hd),
            },
            "facebook_fallback_success"
          );
          const ok: FacebookFallbackOk = {
            ok: true,
            method: lastMethod,
            profile: lastProfile,
            title,
            durationSeconds,
            thumbnailUrl,
            candidates: { hdUrl: hd, sdUrl: sd, dashManifest: lastCandidates.dashManifest },
          };
          return collectDiag ? { result: ok, redirectProbe, steps } : { result: ok };
        }
      }
    }
    if (!candidatesHaveMp4(lastCandidates)) {
      for (const u of extraUrls.slice(0, 10)) {
        const vid = videoIdFromFacebookUrl(u);
        if (
          vid &&
          (await attempt("mbasic_html", `https://mbasic.facebook.com/watch/?v=${encodeURIComponent(vid)}`))
        ) {
          const hd = lastCandidates.hdUrl;
          const sd = lastCandidates.sdUrl;
          const thumbnailUrl = parseThumbnail(lastHtml);
          const durationSeconds = parseDurationSeconds(lastHtml);
          let title = parseTitle(lastHtml);
          if (!title || /^facebook$/i.test(title)) title = "Facebook video";
          logger.info(
            {
              facebook_fallback_success: true,
              method: lastMethod,
              profile: lastProfile,
              urlHost,
              candidateHosts: logHostsFromUrls([hd, sd].filter(Boolean) as string[]),
              durationSeconds,
              hasThumb: Boolean(thumbnailUrl),
              foundSd: Boolean(sd),
              foundHd: Boolean(hd),
            },
            "facebook_fallback_success"
          );
          const ok: FacebookFallbackOk = {
            ok: true,
            method: lastMethod,
            profile: lastProfile,
            title,
            durationSeconds,
            thumbnailUrl,
            candidates: { hdUrl: hd, sdUrl: sd, dashManifest: lastCandidates.dashManifest },
          };
          return collectDiag ? { result: ok, redirectProbe, steps } : { result: ok };
        }
      }
    }
  }

  logger.warn(
    {
      facebook_fallback_failed: true,
      reason: "no_mp4_candidates",
      urlHost,
      profile: lastProfile,
      variant: lastMethod,
    },
    "facebook_fallback_failed"
  );
  const fail: FacebookFallbackFail = { ok: false, reason: "no_mp4_candidates" };
  return collectDiag ? { result: fail, redirectProbe, steps } : { result: fail };
}

/**
 * Run all diagnostic fetches (same order as extraction) with token counts — no full URLs in output structure.
 */
export async function runFacebookFallbackDiagnostics(inputUrl: string): Promise<{
  redirectProbe: { finalUrlHost: string; finalPathLen: number; counts: FacebookHtmlSignalCounts; htmlChars: number };
  steps: FacebookDiagStep[];
  extraction: FacebookFallbackResult;
}> {
  const cookieHeader = tryReadFacebookCookieHeader();
  const { result, redirectProbe, steps } = await facebookFallbackExtractInner(inputUrl, cookieHeader, true);
  return {
    redirectProbe: redirectProbe!,
    steps: steps!,
    extraction: result,
  };
}

/**
 * Full extraction: Desktop Chrome first (post-redirect canonical), then mobile web, then mbasic; extra watch URLs use same order.
 */
export async function extractFacebookDirectMedia(canonicalUrl: string): Promise<FacebookFallbackResult> {
  logger.info({ facebook_fallback_start: true, urlHost: hostOnlyForLog(canonicalUrl) }, "facebook_fallback_start");
  const cookieHeader = tryReadFacebookCookieHeader();
  const { result } = await facebookFallbackExtractInner(canonicalUrl, cookieHeader, false);
  return result;
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
        "User-Agent": FACEBOOK_DESKTOP_CHROME_UA,
        Accept: "*/*",
        "Accept-Encoding": "gzip, deflate, br",
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
