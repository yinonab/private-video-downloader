import type { YtdlpFormatRow, YtdlpVideoInfo } from "./ytdlp";
import { logger } from "./logger";

export type AvailableQualityDto = {
  id: string;
  label: string;
  available: boolean;
  reason: string | null;
};

const NA_REASON = "Not available for this video";

function isVideoRow(f: YtdlpFormatRow): boolean {
  const v = f.vcodec;
  if (typeof v === "string" && v !== "none") return true;
  const h = f.height;
  return typeof h === "number" && Number.isFinite(h) && h > 0;
}

function isAudioCapableRow(f: YtdlpFormatRow): boolean {
  const a = f.acodec;
  return typeof a === "string" && a !== "none";
}

function isAudioOnlyRow(f: YtdlpFormatRow): boolean {
  return isAudioCapableRow(f) && !isVideoRow(f);
}

function rowHasMp4Video(f: YtdlpFormatRow): boolean {
  return isVideoRow(f) && typeof f.ext === "string" && f.ext.toLowerCase() === "mp4";
}

function collectVideoHeights(formats: YtdlpFormatRow[]): number[] {
  const hs = new Set<number>();
  for (const f of formats) {
    if (!isVideoRow(f)) continue;
    const h = f.height;
    if (typeof h === "number" && Number.isFinite(h) && h > 0) hs.add(Math.round(h));
  }
  return [...hs].sort((a, b) => b - a);
}

function hasHeightInRange(formats: YtdlpFormatRow[], minH: number, maxH: number): boolean {
  return formats.some((f) => {
    if (!isVideoRow(f)) return false;
    const h = f.height;
    return typeof h === "number" && h >= minH && h <= maxH;
  });
}

function has480Tier(formats: YtdlpFormatRow[]): boolean {
  return (
    hasHeightInRange(formats, 400, 540) ||
    formats.some((f) => {
      if (!isVideoRow(f)) return false;
      const h = f.height;
      return typeof h === "number" && h >= 360 && h <= 480;
    })
  );
}

function metaLooksDownloadable(meta: YtdlpVideoInfo): boolean {
  return (
    (typeof meta.duration === "number" && meta.duration > 0) ||
    typeof meta.id === "string" ||
    typeof meta.title === "string"
  );
}

export function computeAvailableQualities(
  meta: YtdlpVideoInfo,
  opts: { platform: string; urlHost: string }
): AvailableQualityDto[] {
  const formatsRaw = meta.formats;
  const formats: YtdlpFormatRow[] = Array.isArray(formatsRaw)
    ? formatsRaw.filter((x): x is YtdlpFormatRow => x != null && typeof x === "object")
    : [];

  const heights = collectVideoHeights(formats);
  const maxVideoHeight = heights.length > 0 ? Math.max(...heights) : 0;
  const hasMp4 = formats.some(rowHasMp4Video);
  const anyVideo = formats.some(isVideoRow);
  const hasAudioOnly = formats.some(isAudioOnlyRow);
  const anyAudio = formats.some(isAudioCapableRow) || hasAudioOnly;

  let bestAvail: boolean;
  let v1080: boolean;
  let v720: boolean;
  let v480: boolean;
  let audioAvail: boolean;
  let tiktokReadyAvail: boolean;

  if (formats.length === 0) {
    const ok = metaLooksDownloadable(meta);
    bestAvail = ok;
    audioAvail = ok;
    tiktokReadyAvail = ok;
    v1080 = false;
    v720 = false;
    v480 = false;
  } else {
    bestAvail = anyVideo || metaLooksDownloadable(meta);
    tiktokReadyAvail = bestAvail;
    v1080 = maxVideoHeight >= 1080 || hasHeightInRange(formats, 900, 1080);
    v720 = maxVideoHeight >= 720 || hasHeightInRange(formats, 600, 720);
    v480 = maxVideoHeight >= 480 || has480Tier(formats);
    audioAvail = hasAudioOnly || formats.some(isAudioCapableRow);
  }

  const mk = (id: string, label: string, available: boolean): AvailableQualityDto => ({
    id,
    label,
    available,
    reason: available ? null : NA_REASON,
  });

  const result = [
    mk("best", "Best MP4", bestAvail),
    mk("tiktok_ready", "TikTok-ready MP4", tiktokReadyAvail),
    mk("1080p", "1080p MP4", v1080),
    mk("720p", "720p MP4", v720),
    mk("480p", "480p MP4", v480),
    mk("audio", "Audio MP3", audioAvail),
  ];

  logger.info(
    {
      analyzeQualityProbe: true,
      platform: opts.platform,
      urlHost: opts.urlHost,
      formatCount: formats.length,
      maxVideoHeight,
      videoHeights: heights,
      hasMp4,
      hasAudioTrackGuess: anyAudio,
      availableQualityIds: result.filter((r) => r.available).map((r) => r.id),
    },
    "analyze availableQualities"
  );

  return result;
}
