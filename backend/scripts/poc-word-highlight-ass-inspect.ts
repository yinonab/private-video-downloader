/**
 * Local PoC inspector — prints ASS Dialogue payloads for word-highlight samples.
 * Run: npx tsx scripts/poc-word-highlight-ass-inspect.ts
 * Does not log full transcript files; structural inspection only.
 */
import { segmentsToAssContent } from "../src/services/assSubtitles.service";
import type { TranscriptSegment } from "../src/services/transcription.service";

const base = {
  mode: "segments" as const,
  language: "auto" as const,
  burnIn: true as const,
  style: "clean_pro" as const,
  fontSize: "medium" as const,
  fontFamily: "heebo" as const,
  position: "bottom" as const,
  color: "white" as const,
  offsetX: 0,
  offsetY: 0,
};

const samples: Record<string, TranscriptSegment> = {
  he1: {
    startSec: 0,
    endSec: 3,
    text: "מה משותף לדברים הבאים",
    words: [
      { startSec: 0.0, endSec: 0.5, text: "מה" },
      { startSec: 0.5, endSec: 1.0, text: "משותף" },
      { startSec: 1.0, endSec: 1.5, text: "לדברים" },
      { startSec: 1.5, endSec: 2.0, text: "הבאים" },
    ],
  },
  hePunct: {
    startSec: 0,
    endSec: 2.5,
    text: "שלום, זה מבחן קצר.",
    words: [
      { startSec: 0.0, endSec: 0.6, text: "שלום," },
      { startSec: 0.6, endSec: 1.2, text: "זה" },
      { startSec: 1.2, endSec: 1.8, text: "מבחן" },
      { startSec: 1.8, endSec: 2.5, text: "קצר." },
    ],
  },
  en1: {
    startSec: 0,
    endSec: 3,
    text: "What do these things have in common?",
    words: [
      { startSec: 0.0, endSec: 0.4, text: "What" },
      { startSec: 0.4, endSec: 0.7, text: "do" },
      { startSec: 0.7, endSec: 1.0, text: "these" },
      { startSec: 1.0, endSec: 1.3, text: "things" },
      { startSec: 1.3, endSec: 1.6, text: "have" },
      { startSec: 1.6, endSec: 2.0, text: "in" },
      { startSec: 2.0, endSec: 2.5, text: "common?" },
    ],
  },
};

function dialoguePayloads(ass: string): string[] {
  return ass
    .split("\n")
    .filter((l) => l.startsWith("Dialogue:"))
    .map((l) => l.replace(/^Dialogue:\s*\d+,[^,]+,[^,]+,Default\s*,,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*,(.*)$/i, "$1"));
}

for (const [name, seg] of Object.entries(samples)) {
  for (const wh of ["none", "color", "box"] as const) {
    const ass = segmentsToAssContent([seg], { ...base, wordHighlight: wh, title: `${name}-${wh}` });
    const payloads = dialoguePayloads(ass);
    console.info(`\n--- ${name} wordHighlight=${wh} events=${payloads.length} ---`);
    for (let i = 0; i < Math.min(4, payloads.length); i++) {
      const p = payloads[i]!;
      const overrideCount = (p.match(/\{\\/g) ?? []).length;
      const resetCount = (p.match(/\{\\r\}/g) ?? []).length;
      console.info(`  [${i}] overrides=${overrideCount} resets=${resetCount}`);
      console.info(`  ${p.replace(/\{\\an\d+\\pos\([^}]+\)\}/, "").slice(0, 180)}`);
    }
  }
}
