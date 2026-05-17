/**
 * Dev diagnostic: Facebook fallback fetch order, Desktop Chrome redirect probe, HTML token counts (sanitized).
 * Usage: npx tsx scripts/facebook-fallback-diagnostic.ts "<facebook-url>"
 */
import { runFacebookFallbackDiagnostics } from "../src/services/facebookFallbackExtractor";

async function main(): Promise<void> {
  const url = process.argv[2]?.trim();
  if (!url) {
    console.error("Usage: npx tsx scripts/facebook-fallback-diagnostic.ts \"<facebook-url>\"");
    process.exit(1);
  }

  const r = await runFacebookFallbackDiagnostics(url);

  const extractionSummary =
    r.extraction.ok === true
      ? {
          ok: true as const,
          method: r.extraction.method,
          profile: r.extraction.profile,
          foundSd: Boolean(r.extraction.candidates.sdUrl),
          foundHd: Boolean(r.extraction.candidates.hdUrl),
          dashManifest: Boolean(r.extraction.candidates.dashManifest),
          candidateHosts: [
            ...new Set(
              [r.extraction.candidates.sdUrl, r.extraction.candidates.hdUrl]
                .filter(Boolean)
                .map((u) => {
                  try {
                    return new URL(u).hostname;
                  } catch {
                    return null;
                  }
                })
                .filter(Boolean)
            ),
          ],
        }
      : { ok: false as const, reason: r.extraction.reason };

  console.log(
    JSON.stringify(
      {
        redirectAfterDesktopChrome: r.redirectProbe,
        steps: r.steps.map((s) => ({
          profile: s.profile,
          variant: s.method,
          requestUrlHost: s.requestUrlHost,
          finalUrlHost: s.finalUrlHost,
          htmlChars: s.htmlChars,
          counts: s.counts,
          extractedSd: s.extractedSd,
          extractedHd: s.extractedHd,
          candidateHosts: s.candidateHosts,
        })),
        extraction: extractionSummary,
        candidatesExtracted: r.extraction.ok === true,
      },
      null,
      2
    )
  );

  if (!r.extraction.ok) process.exit(2);
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : String(e));
  process.exit(1);
});
