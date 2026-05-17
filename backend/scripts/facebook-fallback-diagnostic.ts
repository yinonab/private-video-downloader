/**
 * Dev diagnostic: runs facebookFallbackExtractor with sanitized stdout only.
 * Usage: npx tsx scripts/facebook-fallback-diagnostic.ts "<facebook-url>"
 */
import { extractFacebookDirectMedia } from "../src/services/facebookFallbackExtractor";

function hostOnly(u: string | undefined): string | null {
  if (!u) return null;
  try {
    return new URL(u).hostname;
  } catch {
    return "invalid";
  }
}

async function main(): Promise<void> {
  const url = process.argv[2]?.trim();
  if (!url) {
    console.error("Usage: npx tsx scripts/facebook-fallback-diagnostic.ts \"<facebook-url>\"");
    process.exit(1);
  }

  const r = await extractFacebookDirectMedia(url);
  if (!r.ok) {
    console.log(JSON.stringify({ ok: false, reason: r.reason }, null, 2));
    process.exit(2);
    return;
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        method: r.method,
        titlePresent: Boolean(r.title && r.title.trim()),
        durationSeconds: r.durationSeconds ?? null,
        hasThumbnail: Boolean(r.thumbnailUrl),
        sd: Boolean(r.candidates.sdUrl),
        hd: Boolean(r.candidates.hdUrl),
        dashManifest: Boolean(r.candidates.dashManifest),
        candidateHosts: [hostOnly(r.candidates.sdUrl), hostOnly(r.candidates.hdUrl)].filter(Boolean),
      },
      null,
      2
    )
  );
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : String(e));
  process.exit(1);
});
