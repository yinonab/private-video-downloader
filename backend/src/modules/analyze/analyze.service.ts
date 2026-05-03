import { PrismaClient } from "@prisma/client";
import { fetchMetadataJson } from "../../services/ytdlp";
import { assertUrlSafeForFetch, normalizeUrl } from "../../services/urlSafety";
import { extractorToPlatform } from "../../services/platform";
import { AppError, codes } from "../../types/errors";
import { hashUrl } from "../../services/hashing";

const AVAILABLE_FORMATS = [
  { label: "Best MP4", value: "best", type: "video" },
  { label: "1080p MP4", value: "1080p", type: "video" },
  { label: "720p MP4", value: "720p", type: "video" },
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

  let meta;
  try {
    meta = await fetchMetadataJson(normalized);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new AppError(codes.ANALYZE_FAILED, "Could not analyze URL", 502, msg.slice(0, 500));
  }

  const platform = extractorToPlatform(meta.extractor);
  const urlHash = hashUrl(normalized);

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
    availableFormats: [...AVAILABLE_FORMATS],
  };
}
