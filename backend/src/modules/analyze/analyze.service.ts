import { PrismaClient } from "@prisma/client";
import { computeAvailableQualities } from "../../services/availableQualities";
import {
  fetchMetadataJson,
  stderrIndicatesFacebookCannotParseData,
  YtdlpMetadataError,
  ytDlpCookiesOperationalFlags,
  type YtdlpFormatRow,
  type YtdlpVideoInfo,
} from "../../services/ytdlp";
import {
  analyzeFailureCooldownKey,
  mapYtdlpAnalyzeFailure,
} from "../../services/ytdlpAnalyzeErrors";
import {
  assertUrlSafeForFetch,
  hostnameIsFacebook,
  hostnameIsThreads,
  normalizeUrl,
} from "../../services/urlSafety";
import { logger } from "../../services/logger";
import { extractorToPlatform } from "../../services/platform";
import { AppError, codes } from "../../types/errors";
import { hashUrl } from "../../services/hashing";
import { extractFacebookDirectMedia } from "../../services/facebookFallbackExtractor";
import {
  analyzeErrorCodeForYtdlpClassification,
  notifyAnalyzeFailedGeneric,
  notifyFacebookNoMp4CandidatesAlert,
  safeHostFromUrlString,
  tryNotifyInstagramYtDlpCritical,
} from "../../services/operationalAlerts";
import {
  countYtdlpFormats,
  logAnalyzePerf,
  startPerfTimer,
} from "../../services/analyzePerf";
import {
  lookupAnalyzeResultCache,
  storeAnalyzeResultCache,
  type AnalyzeResponseDto,
  type AnalyzeResultCacheRedis,
} from "../../services/analyzeResultCache";

export type { AnalyzeResponseDto, AnalyzeResultCacheRedis };

const AVAILABLE_FORMATS_LEGACY = [
  { label: "Best MP4", value: "best", type: "video" },
  { label: "1080p MP4", value: "1080p", type: "video" },
  { label: "720p MP4", value: "720p", type: "video" },
  { label: "480p MP4", value: "480p", type: "video" },
  { label: "Audio MP3", value: "audio_mp3", type: "audio" },
] as const;

/** Same-process in-flight dedupe (cross-instance cache is Redis). */
const analyzeInflight = new Map<string, Promise<AnalyzeResponseDto>>();

/** @internal test helper */
export function resetAnalyzeInflightForTests(): void {
  analyzeInflight.clear();
}

export type AnalyzeUrlOptions = {
  redis?: AnalyzeResultCacheRedis | null;
  /** Test seam — defaults to production `fetchMetadataJson`. */
  fetchMetadata?: (url: string) => Promise<YtdlpVideoInfo>;
  /** Test seam — defaults to production `extractFacebookDirectMedia`. */
  extractFacebook?: typeof extractFacebookDirectMedia;
  /** Test seam — defaults to production `assertUrlSafeForFetch`. */
  assertUrlSafe?: (url: string) => Promise<void>;
};

function buildSyntheticFacebookYtdlpMeta(
  canonicalUrl: string,
  fb: {
    title?: string;
    thumbnailUrl?: string;
    durationSeconds?: number;
    candidates: { hdUrl?: string; sdUrl?: string };
  }
): YtdlpVideoInfo {
  const formats: YtdlpFormatRow[] = [];
  const { hdUrl, sdUrl } = fb.candidates;

  if (sdUrl) {
    formats.push({
      format_id: "fb_fallback_sd",
      ext: "mp4",
      height: 480,
      width: 854,
      vcodec: "h264",
      acodec: "none",
    });
  }
  if (hdUrl) {
    const low = hdUrl.toLowerCase();
    const height = /\b1080|1920|basic-gen2_1080|tag=[^&]*1080/i.test(low) ? 1080 : 720;
    formats.push({
      format_id: "fb_fallback_hd",
      ext: "mp4",
      height,
      width: height >= 1080 ? 1920 : 1280,
      vcodec: "h264",
      acodec: "none",
    });
  }

  return {
    id: "facebook_fallback",
    title: fb.title,
    thumbnail: fb.thumbnailUrl,
    duration: fb.durationSeconds,
    extractor: "facebook",
    webpage_url: canonicalUrl,
    formats,
  };
}

function handleYtdlpAnalyzeError(err: YtdlpMetadataError, urlHost: string): never {
  const mapped = mapYtdlpAnalyzeFailure(err.classification, urlHost, err.stderrTail);
  if (mapped) {
    throw new AppError(mapped.code, mapped.message, mapped.statusCode, undefined, {
      classification: mapped.classification,
      ...(mapped.platform ? { platform: mapped.platform } : {}),
    });
  }

  if (err.classification === "drm_protected") {
    throw new AppError(
      codes.DRM_PROTECTED,
      "This link can't be downloaded because the content is DRM-protected.",
      422
    );
  }
  if (err.classification === "unsupported_url") {
    if (hostnameIsThreads(urlHost)) {
      throw new AppError(
        codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
        "Threads links are not supported for download yet.",
        400
      );
    }
    throw new AppError(codes.LINKCLIP_ERR_PLATFORM_UNSUPPORTED, "This link is not supported for download yet.", 400);
  }
  if (err.classification === "format_unavailable") {
    throw new AppError(
      codes.LINKCLIP_ERR_ANALYZE_METADATA_UNAVAILABLE,
      "Could not load video format information for this link.",
      422
    );
  }
  throw new AppError(codes.ANALYZE_FAILED, "Could not analyze URL", 502);
}

function logAnalyzeFailureTotal(opts: {
  totalMs: number;
  urlHost?: string;
  platform?: string;
  classification: string;
  result?: string;
}): void {
  logAnalyzePerf({
    stage: "analyze_total",
    durationMs: opts.totalMs,
    urlHost: opts.urlHost,
    platform: opts.platform,
    cacheHit: false,
    result: opts.result ?? "failure",
    classification: opts.classification,
  });
}

async function runFreshAnalyze(opts: {
  prisma: PrismaClient;
  normalized: string;
  urlHost: string;
  urlHash: string;
  totalTimer: { elapsedMs: () => number };
  fetchMetadata: (url: string) => Promise<YtdlpVideoInfo>;
  extractFacebook: typeof extractFacebookDirectMedia;
}): Promise<AnalyzeResponseDto> {
  const { prisma, normalized, urlHost, urlHash, totalTimer, fetchMetadata, extractFacebook } = opts;
  let platformHint: string | undefined;

  let meta: YtdlpVideoInfo;
  let usedFacebookFallback = false;

  const ytdlpTimer = startPerfTimer();
  try {
    meta = await fetchMetadata(normalized);
    logAnalyzePerf({
      stage: "analyze_ytdlp_metadata",
      durationMs: ytdlpTimer.elapsedMs(),
      urlHost,
      formatCount: countYtdlpFormats(meta),
      result: "success",
      cacheHit: false,
    });
  } catch (err) {
    const ytdlpMs = ytdlpTimer.elapsedMs();
    if (!(err instanceof YtdlpMetadataError)) {
      logAnalyzePerf({
        stage: "analyze_ytdlp_metadata",
        durationMs: ytdlpMs,
        urlHost,
        result: "failure",
        classification: "unexpected_metadata_error",
      });
      logger.warn({ err }, "analyze unexpected failure");
      notifyAnalyzeFailedGeneric({
        urlHost,
        classification: "unexpected_metadata_error",
        errorCode: codes.ANALYZE_FAILED,
        actionHint: "Non-yt-dlp error during metadata fetch — inspect logs.",
      });
      logAnalyzeFailureTotal({
        totalMs: totalTimer.elapsedMs(),
        urlHost,
        classification: "unexpected_metadata_error",
      });
      throw new AppError(codes.ANALYZE_FAILED, "Could not analyze URL", 502);
    }

    const mapped = mapYtdlpAnalyzeFailure(err.classification, urlHost, err.stderrTail);
    const errorCode =
      mapped?.code ?? analyzeErrorCodeForYtdlpClassification(err.classification);
    const logClassification = mapped?.classification ?? err.classification;
    const platform = mapped?.platform;
    platformHint = platform;
    const statusCode = mapped?.statusCode ?? 502;
    const cookieFlags = ytDlpCookiesOperationalFlags();

    logAnalyzePerf({
      stage: "analyze_ytdlp_metadata",
      durationMs: ytdlpMs,
      urlHost,
      platform: platform ?? undefined,
      result: "failure",
      classification: logClassification,
    });

    logger.warn(
      {
        classification: logClassification,
        code: errorCode,
        urlHost,
        platform: platform ?? "unknown",
        statusCode,
        cooldownKey: analyzeFailureCooldownKey(logClassification, urlHost),
        hasCookiesConfigured: cookieFlags.hasCookiesConfigured,
        tempCookieUsed: cookieFlags.tempCookieUsed,
      },
      "analyze yt-dlp metadata failed"
    );

    const instagramNotified = tryNotifyInstagramYtDlpCritical({
      context: "analyze",
      urlHost,
      platformLabel: "unknown",
      classification: err.classification,
      stderrTail: err.stderrTail,
    });

    const facebookParseFail =
      hostnameIsFacebook(urlHost) && stderrIndicatesFacebookCannotParseData(err.stderrTail);

    if (facebookParseFail) {
      const fb = await extractFacebook(normalized);
      if (!fb.ok) {
        if (fb.reason === "no_mp4_candidates") {
          notifyFacebookNoMp4CandidatesAlert({ context: "analyze", urlHost });
        } else {
          notifyAnalyzeFailedGeneric({
            urlHost,
            classification: "facebook_fallback_failed",
            errorCode: codes.FACEBOOK_EXTRACT_FAILED,
            platformLabel: "facebook",
            actionHint: "Facebook HTML fallback failed — inspect extractor logs.",
          });
        }
        logAnalyzeFailureTotal({
          totalMs: totalTimer.elapsedMs(),
          urlHost,
          platform: "facebook",
          classification: "facebook_fallback_failed",
        });
        throw new AppError(
          codes.FACEBOOK_EXTRACT_FAILED,
          "We couldn't read this Facebook video right now. This link may require special access or Facebook may be blocking access to it. Try another link or try again later.",
          422
        );
      }
      meta = buildSyntheticFacebookYtdlpMeta(normalized, fb);
      usedFacebookFallback = true;
    } else {
      if (!instagramNotified) {
        notifyAnalyzeFailedGeneric({
          urlHost,
          classification: logClassification,
          errorCode,
          platformLabel: platform,
          actionHint:
            err.classification === "drm_protected"
              ? "DRM-protected source — not supported; no bypass attempted."
              : "Check platform support or yt-dlp metadata path.",
        });
      }
      logAnalyzeFailureTotal({
        totalMs: totalTimer.elapsedMs(),
        urlHost,
        platform: platformHint,
        classification: logClassification,
      });
      handleYtdlpAnalyzeError(err, urlHost);
    }
  }

  const parseTimer = startPerfTimer();
  const platform = extractorToPlatform(meta.extractor);
  platformHint = platform ?? meta.extractor ?? undefined;
  const title = meta.title ?? "Untitled";
  const durationSec = meta.duration != null ? Math.floor(meta.duration) : undefined;
  const thumbnail = meta.thumbnail;
  const thumbnailPresent = typeof thumbnail === "string" && thumbnail.trim().length > 0;
  const formatCount = countYtdlpFormats(meta);
  logAnalyzePerf({
    stage: "analyze_parse_metadata",
    durationMs: parseTimer.elapsedMs(),
    urlHost,
    platform: platformHint,
    formatCount,
    thumbnailPresent,
    result: usedFacebookFallback ? "facebook_fallback" : "ok",
  });

  const qualitiesTimer = startPerfTimer();
  const availableQualities = computeAvailableQualities(meta, {
    platform: platform ?? meta.extractor ?? "unknown",
    urlHost,
  });
  logAnalyzePerf({
    stage: "analyze_qualities",
    durationMs: qualitiesTimer.elapsedMs(),
    urlHost,
    platform: platformHint,
    formatCount,
    qualityCount: availableQualities.length,
    result: "ok",
  });

  const upsertTimer = startPerfTimer();
  await prisma.link.upsert({
    where: { urlHash },
    create: {
      url: normalized,
      urlHash,
      title: meta.title ?? null,
      thumbnail: meta.thumbnail ?? null,
      durationSec: meta.duration != null ? Math.floor(meta.duration) : null,
      extractor: meta.extractor ?? null,
      platform: platform ?? null,
      facebookDirectFallback: usedFacebookFallback,
    },
    update: {
      title: meta.title ?? undefined,
      thumbnail: meta.thumbnail ?? undefined,
      durationSec: meta.duration != null ? Math.floor(meta.duration) : undefined,
      extractor: meta.extractor ?? undefined,
      platform: platform ?? undefined,
      facebookDirectFallback: usedFacebookFallback,
    },
  });
  logAnalyzePerf({
    stage: "analyze_link_upsert",
    durationMs: upsertTimer.elapsedMs(),
    urlHost,
    platform: platformHint,
    result: "ok",
  });

  const responsePlatform = platform ?? meta.extractor ?? "unknown";
  const dto: AnalyzeResponseDto = {
    url: normalized,
    platform: responsePlatform,
    title,
    durationSec,
    thumbnail,
    extractor: meta.extractor ?? "unknown",
    availableFormats: [...AVAILABLE_FORMATS_LEGACY],
    availableQualities,
  };

  logAnalyzePerf({
    stage: "analyze_total",
    durationMs: totalTimer.elapsedMs(),
    urlHost,
    platform: responsePlatform,
    formatCount,
    qualityCount: availableQualities.length,
    thumbnailPresent,
    cacheHit: false,
    result: "success",
  });

  return dto;
}

export async function analyzeUrl(
  prisma: PrismaClient,
  urlRaw: string,
  options?: AnalyzeUrlOptions
): Promise<AnalyzeResponseDto> {
  const totalTimer = startPerfTimer();
  const redis = options?.redis ?? null;
  const fetchMetadata = options?.fetchMetadata ?? fetchMetadataJson;
  const extractFacebook = options?.extractFacebook ?? extractFacebookDirectMedia;
  const assertUrlSafe = options?.assertUrlSafe ?? assertUrlSafeForFetch;

  let urlHost = "unknown";

  const platformDetectTimer = startPerfTimer();
  let normalized: string;
  try {
    normalized = normalizeUrl(urlRaw);
  } catch (e) {
    const host = safeHostFromUrlString(urlRaw);
    logAnalyzePerf({
      stage: "analyze_platform_detect",
      durationMs: platformDetectTimer.elapsedMs(),
      urlHost: host,
      result: "invalid_url",
    });
    if (e instanceof AppError) {
      notifyAnalyzeFailedGeneric({
        urlHost: host,
        classification: "invalid_url",
        errorCode: e.code,
      });
      logAnalyzeFailureTotal({
        totalMs: totalTimer.elapsedMs(),
        urlHost: host,
        classification: "invalid_url",
      });
      throw e;
    }
    notifyAnalyzeFailedGeneric({
      urlHost: host,
      classification: "invalid_url",
      errorCode: codes.INVALID_URL,
    });
    logAnalyzeFailureTotal({
      totalMs: totalTimer.elapsedMs(),
      urlHost: host,
      classification: "invalid_url",
    });
    throw new AppError(codes.INVALID_URL, "Invalid URL", 400);
  }

  try {
    urlHost = new URL(normalized).hostname.toLowerCase();
  } catch {
    /* ignore */
  }

  try {
    await assertUrlSafe(normalized);
  } catch (e) {
    logAnalyzePerf({
      stage: "analyze_platform_detect",
      durationMs: platformDetectTimer.elapsedMs(),
      urlHost,
      result: "url_safety_blocked",
    });
    if (e instanceof AppError) {
      notifyAnalyzeFailedGeneric({
        urlHost,
        classification: "url_safety_blocked",
        errorCode: e.code,
        actionHint: "Private IP, blocked host, or DNS policy rejected this URL.",
      });
    }
    logAnalyzeFailureTotal({
      totalMs: totalTimer.elapsedMs(),
      urlHost,
      classification: "url_safety_blocked",
    });
    throw e;
  }

  if (hostnameIsThreads(urlHost)) {
    logAnalyzePerf({
      stage: "analyze_platform_detect",
      durationMs: platformDetectTimer.elapsedMs(),
      urlHost,
      result: "threads_unsupported",
    });
    notifyAnalyzeFailedGeneric({
      urlHost,
      classification: "threads_unsupported",
      errorCode: codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
      actionHint: "Threads links are blocked by product policy.",
    });
    logAnalyzeFailureTotal({
      totalMs: totalTimer.elapsedMs(),
      urlHost,
      classification: "threads_unsupported",
    });
    throw new AppError(
      codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
      "Threads links are not supported for download yet.",
      400
    );
  }

  logAnalyzePerf({
    stage: "analyze_platform_detect",
    durationMs: platformDetectTimer.elapsedMs(),
    urlHost,
    result: "ok",
    cacheHit: false,
  });

  const urlHash = hashUrl(normalized);

  const cacheLookupTimer = startPerfTimer();
  const cacheLookup = await lookupAnalyzeResultCache(redis, urlHash);
  if (cacheLookup.status === "hit") {
    logAnalyzePerf({
      stage: "analyze_cache_lookup",
      durationMs: cacheLookupTimer.elapsedMs(),
      urlHost,
      platform: cacheLookup.dto.platform,
      cacheHit: true,
      result: "redis_hit",
      qualityCount: cacheLookup.dto.availableQualities.length,
    });
    logAnalyzePerf({
      stage: "analyze_total",
      durationMs: totalTimer.elapsedMs(),
      urlHost,
      platform: cacheLookup.dto.platform,
      cacheHit: true,
      result: "success",
      qualityCount: cacheLookup.dto.availableQualities.length,
      thumbnailPresent:
        typeof cacheLookup.dto.thumbnail === "string" && cacheLookup.dto.thumbnail.trim().length > 0,
    });
    return cacheLookup.dto;
  }

  logAnalyzePerf({
    stage: "analyze_cache_lookup",
    durationMs: cacheLookupTimer.elapsedMs(),
    urlHost,
    cacheHit: false,
    result:
      cacheLookup.status === "error"
        ? "redis_error"
        : cacheLookup.status === "skipped"
          ? "redis_skipped"
          : "redis_miss",
  });

  const existing = analyzeInflight.get(urlHash);
  if (existing) {
    const waitTimer = startPerfTimer();
    try {
      const dto = await existing;
      logAnalyzePerf({
        stage: "analyze_inflight_wait",
        durationMs: waitTimer.elapsedMs(),
        urlHost,
        platform: dto.platform,
        cacheHit: false,
        result: "joined",
      });
      logAnalyzePerf({
        stage: "analyze_total",
        durationMs: totalTimer.elapsedMs(),
        urlHost,
        platform: dto.platform,
        cacheHit: false,
        result: "success",
        qualityCount: dto.availableQualities.length,
      });
      return dto;
    } catch (e) {
      logAnalyzePerf({
        stage: "analyze_inflight_wait",
        durationMs: waitTimer.elapsedMs(),
        urlHost,
        cacheHit: false,
        result: "joined_failure",
      });
      const classification =
        e instanceof AppError
          ? e.code
          : "joined_failure";
      logAnalyzeFailureTotal({
        totalMs: totalTimer.elapsedMs(),
        urlHost,
        classification,
      });
      throw e;
    }
  }

  const work = (async (): Promise<AnalyzeResponseDto> => {
    const dto = await runFreshAnalyze({
      prisma,
      normalized,
      urlHost,
      urlHash,
      totalTimer,
      fetchMetadata,
      extractFacebook,
    });
    await storeAnalyzeResultCache(redis, urlHash, dto);
    return dto;
  })();

  analyzeInflight.set(urlHash, work);
  try {
    return await work;
  } finally {
    if (analyzeInflight.get(urlHash) === work) {
      analyzeInflight.delete(urlHash);
    }
  }
}
