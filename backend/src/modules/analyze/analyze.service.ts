import { PrismaClient } from "@prisma/client";
import { computeAvailableQualities } from "../../services/availableQualities";
import { fetchMetadataJson, YtdlpMetadataError } from "../../services/ytdlp";
import { assertUrlSafeForFetch, hostnameIsThreads, normalizeUrl } from "../../services/urlSafety";
import { logger } from "../../services/logger";
import { extractorToPlatform } from "../../services/platform";
import { AppError, codes } from "../../types/errors";
import { hashUrl } from "../../services/hashing";

const AVAILABLE_FORMATS_LEGACY = [
  { label: "Best MP4", value: "best", type: "video" },
  { label: "1080p MP4", value: "1080p", type: "video" },
  { label: "720p MP4", value: "720p", type: "video" },
  { label: "480p MP4", value: "480p", type: "video" },
  { label: "Audio MP3", value: "audio_mp3", type: "audio" },
] as const;

export async function analyzeUrl(prisma: PrismaClient, urlRaw: string) {
  let normalized: string;
  try {
    normalized = normalizeUrl(urlRaw);
  } catch (e) {
    if (e instanceof AppError) throw e;
    throw new AppError(codes.INVALID_URL, "Invalid URL", 400);
  }

  await assertUrlSafeForFetch(normalized);

  let urlHost = "unknown";
  try {
    urlHost = new URL(normalized).hostname.toLowerCase();
  } catch {
    /* ignore */
  }

  if (hostnameIsThreads(urlHost)) {
    throw new AppError(
      codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
      "Threads links are not supported for download yet.",
      400
    );
  }

  let meta;
  try {
    meta = await fetchMetadataJson(normalized);
  } catch (err) {
    if (err instanceof YtdlpMetadataError) {
      logger.warn({ classification: err.classification, urlHost }, "analyze yt-dlp metadata failed");
      if (err.classification === "unsupported_url") {
        if (hostnameIsThreads(urlHost)) {
          throw new AppError(
            codes.LINKCLIP_ERR_THREADS_UNSUPPORTED,
            "Threads links are not supported for download yet.",
            400
          );
        }
        throw new AppError(
          codes.LINKCLIP_ERR_PLATFORM_UNSUPPORTED,
          "This link is not supported for download yet.",
          400
        );
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
    logger.warn({ err }, "analyze unexpected failure");
    throw new AppError(codes.ANALYZE_FAILED, "Could not analyze URL", 502);
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
    },
    update: {
      title: meta.title ?? undefined,
      thumbnail: meta.thumbnail ?? undefined,
      durationSec: meta.duration != null ? Math.floor(meta.duration) : undefined,
      extractor: meta.extractor ?? undefined,
      platform: platform ?? undefined,
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
