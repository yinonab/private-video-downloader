import type { TranscriptSegment } from "../../services/transcription.service";

function trimText(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.trim();
}

/**
 * Canonicalize client caption cues for ASS burn-in: trim/drop blanks, sort, shrink overlaps safely.
 * Does not validate raw numeric ranges beyond basic finiteness.
 */
export function normalizeCaptionSegmentsForBurn(
  input: readonly { readonly startSec: number; readonly endSec: number; readonly text: string }[]
): TranscriptSegment[] {
  const EPS = 1e-4;

  type Prep = { startSec: number; endSec: number; text: string };
  const prepared: Prep[] = [];

  for (const raw of input) {
    const text = trimText(raw.text);
    if (text.length === 0) continue;
    const s = raw.startSec;
    const e = raw.endSec;
    if (!Number.isFinite(s) || !Number.isFinite(e)) continue;
    if (s < 0 || e <= s + EPS) continue;
    prepared.push({ startSec: s, endSec: e, text });
  }

  prepared.sort((a, b) => a.startSec - b.startSec);

  const out: TranscriptSegment[] = [];

  for (const row of prepared) {
    let s = row.startSec;
    let eIn = row.endSec;

    while (out.length > 0 && s < out[out.length - 1]!.endSec) {
      const p = out[out.length - 1]!;
      if (s <= p.startSec + EPS) {
        out.pop();
        continue;
      }
      p.endSec = Math.max(p.startSec + EPS * 10, Math.min(p.endSec, s));
      if (p.endSec <= p.startSec + EPS) {
        out.pop();
        continue;
      }
      break;
    }

    if (out.length > 0) {
      const last = out[out.length - 1]!;
      s = Math.max(s, last.endSec);
    }
    if (eIn <= s + EPS) continue;
    out.push({ startSec: s, endSec: eIn, text: row.text });
  }

  return out;
}
