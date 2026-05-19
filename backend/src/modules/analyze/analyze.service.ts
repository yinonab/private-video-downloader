import { PrismaClient } from "@prisma/client";
import { computeAvailableQualities } from "../../services/availableQualities";
import {
  fetchMetadataJson,
  stderrIndicatesFacebookCannotParseData,
  YtdlpMetadataError,
  type YtdlpFormatRow,
  type YtdlpVideoInfo,
} from "../../services/ytdlp";
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

const AVAILABLE_FORMATS_LEGACY = [
  { label: "Best MP4", value: "best", type: "video" },
  { label: "1080p MP4", value: "1080p", type: "video" },
  { label: "720p MP4", value: "720p", type: "video" },
  { label: "480p MP4", value: "480p", type: "video" },
  { label: "Audio MP3", value: "audio_mp3", type: "audio" },
] as const;

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

export async function analyzeUrl(prisma: PrismaClient, urlRaw: string) {
  let normalized: string;
  try {
    normalized = normalizeUrl(urlRaw);
  } catch (e) {
    const host = safeHostFromUrlString(urlRaw);
    if (e instanceof AppError) {
      notifyAnalyzeFailedGeneric({
        urlHost: host,
        classification: "invalid_url",
        errorCode: e.code,
      });
      throw e;
    }
    notifyAnalyzeFailedGeneric({
      urlHost: host,
      classification: "invalid_url",
      errorCode: codes.INVALID_URL,
    });
    throw new AppError(codes.INVALID_URL, "Invalid URL", 400);
  }

  let urlHost = "unknown";
  try {
    urlHost = new URL(normalized).hostname.toLowerCase();
  } catch {
    /* ignore */
  }

  try {
    await assertUrlSafeForFetch(normalized);
  } catch (e) {
    if (e instanceof AppError) {
      notifyAnalyzeFailedGeneric({
        urlHost,
        classification: "url_safety_blocked",
        errorCode: e.code,
        actionHint: "Private IP, blocked host, or DNS policy rejected this URL.",
      });
    }
    throw e;
  }

  if (hostnameIsThreads(urlHost)) {
    notifyAnalyzeFailedGeneric({
      urlHost,
      classification: "threads_unsupported",
      errorCode: codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
      actionHint: "Threads links are blocked by product policy.",
    });
    throw new AppError(
      codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
      "Threads links are not supported for download yet.",
      400
    );
  }

  let meta: YtdlpVideoInfo;
  let usedFacebookFallback = false;

  try {
    meta = await fetchMetadataJson(normalized);
  } catch (err) {
    if (!(err instanceof YtdlpMetadataError)) {
      logger.warn({ err }, "analyze unexpected failure");
      notifyAnalyzeFailedGeneric({
        urlHost,
        classification: "unexpected_metadata_error",
        errorCode: codes.ANALYZE_FAILED,
        actionHint: "Non-yt-dlp error during metadata fetch — inspect logs.",
      });
      throw new AppError(codes.ANALYZE_FAILED, "Could not analyze URL", 502);
    }

    logger.warn({ classification: err.classification, urlHost }, "analyze yt-dlp metadata failed");

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
      const fb = await extractFacebookDirectMedia(normalized);
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
          classification: err.classification,
          errorCode: analyzeErrorCodeForYtdlpClassification(err.classification),
          actionHint: "Check platform support or yt-dlp metadata path.",
        });
      }
      handleYtdlpAnalyzeError(err, urlHost);
    }
  }

  const platform = extractorToPlatform(meta.extractor);
  const urlHash = hashUrl(normalized);

  const availableQualities = computeAvailableQualities(meta, {
    platform: platform ?? meta.extractor ?? "unknown",
    urlHost,
  });

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

  return {
    url: normalized,
    platform: platform ?? meta.extractor ?? "unknown",
    title: meta.title ?? "Untitled",
    durationSec: meta.duration != null ? Math.floor(meta.duration) : undefined,
    thumbnail: meta.thumbnail,
    extractor: meta.extractor ?? "unknown",
    availableFormats: [...AVAILABLE_FORMATS_LEGACY],
    availableQualities,
  };
}
