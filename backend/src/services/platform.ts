/** Map yt-dlp extractor id to coarse platform label for UI */
export function extractorToPlatform(extractor: string | undefined): string | undefined {
  if (!extractor) return undefined;
  const e = extractor.toLowerCase();
  if (e.includes("youtube")) return "youtube";
  if (e.includes("tiktok")) return "tiktok";
  if (e.includes("instagram")) return "instagram";
  if (e.includes("twitter") || e.includes("x.com")) return "twitter";
  if (e.includes("facebook")) return "facebook";
  if (e.includes("vimeo")) return "vimeo";
  if (e.includes("reddit")) return "reddit";
  if (e.includes("thread")) return "threads";
  return extractor;
}
