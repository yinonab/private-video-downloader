/**
 * Regression checks for ASS caption text hygiene (no transcript logging).
 * Run: npm run diag:ass-captions
 */
import assert from "node:assert/strict";

import type { SegmentsToAssOpts } from "../src/services/assSubtitles.service";
import {
  joinAssLines,
  normalizeCaptionText,
  segmentsToAssContent,
  segmentToDialogueEventsForTests,
} from "../src/services/assSubtitles.service";
import type { TranscriptSegment } from "../src/services/transcription.service";

const baseOpts: SegmentsToAssOpts = {
  mode: "auto",
  language: "auto",
  burnIn: true,
  style: "clean",
  fontSize: "medium",
  position: "bottom",
  color: "white",
  offsetX: 0,
  offsetY: 0,
};

/** Text field (10th field) of a v4+ Dialogue line — minimal scanner, no `\N` in transcript in these tests. */
function extractAssDialogueTextField(line: string): string {
  if (!/^Dialogue:/i.test(line.trimStart())) return "";
  let i = line.indexOf(":") + 1;
  for (let comma = 0; comma < 9; comma++) {
    const j = line.indexOf(",", i);
    if (j < 0) return "";
    i = j + 1;
  }
  return line.slice(i);
}

function dialogueLines(ass: string): string[] {
  return ass.split("\n").flatMap((ln) => (/^Dialogue:/i.test(ln.trimStart()) ? [ln] : []));
}

// --- normalizeCaptionText
assert.equal(normalizeCaptionText("שלום עולם"), "שלום עולם");
assert.equal(normalizeCaptionText("25/5"), "25/5");
assert.equal(normalizeCaptionText("ו/או"), "ו/או");

for (const buggy of [
  "שלום \\\\N עולם",
  "שלום \\N עולם",
  "שלום /N עולם",
  "שלום /n עולם",
  "שלום \\ עולם",
]) {
  const out = normalizeCaptionText(buggy);
  assert.ok(!/\\/u.test(out), `stray backslash: ${buggy} → ${out}`);
  assert.ok(!/\/n$/iu.test(out.trim()), buggy);
}

const twoLine = joinAssLines(["שלום עולם זה משפט ארוך מאוד שנשבר", "לשורה שנייה כאן"]);
assert.ok(twoLine.includes("\\N"), "single ASS hard break");
assert.ok(!twoLine.includes("\\\\N"), "must not contain doubled break token");
assert.ok(twoLine.split("\\N").length === 2, "exactly two lines");

const events = segmentToDialogueEventsForTests(
  { startSec: 0, endSec: 15, text: "שורה ארוכה ".repeat(20).trim() },
  24,
);
assert.ok(events.length >= 1);
for (const ev of events) {
  assert.ok(!ev.text.includes("\\\\N"), `event has \\\\N: ${JSON.stringify(ev.text)}`);
}

const ass = segmentsToAssContent(
  [
    {
      startSec: 0,
      endSec: 4,
      text: 'broken markers: \\\\N \\N /N וגם 25/5 ו/או',
    } satisfies TranscriptSegment,
  ],
  { ...baseOpts, title: "test" },
);

for (const dl of dialogueLines(ass)) {
  const field = extractAssDialogueTextField(dl);
  assert.ok(!field.includes("\\\\N"), `ASS field: ${field}`);
  assert.ok(!/\/n(?![a-z])/iu.test(field.replace(/\\,/g, "")), "raw /N leak");
}

console.log("diag:ass-captions — ok");
