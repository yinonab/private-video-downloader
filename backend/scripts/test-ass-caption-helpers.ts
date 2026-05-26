/**
 * Regression checks for ASS caption text hygiene (no transcript logging).
 * Run: npm run diag:ass-captions
 */
import assert from "node:assert/strict";

import type { SegmentsToAssOpts } from "../src/services/assSubtitles.service";
import {
  escapeAssTextLine,
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

/**
 * Payload after our fixed `Dialogue: 0,start,end,Default,,0,0,0,,` prefix (override + caption text).
 * Robust when caption text contains commas (no `\,` escaping).
 */
function extractOurDialogueCaptionPayload(line: string): string {
  const m = line.match(
    /^Dialogue:\s*\d+,[^,]+,[^,]+,Default\s*,,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*,(.*)$/i,
  );
  return m?.[1] ?? "";
}

/** Caption body after `{...}` pos/align override (that block legitimately contains `\,`). */
function stripLeadingAssOverride(payload: string): string {
  if (!payload.startsWith("{")) return payload;
  const end = payload.indexOf("}");
  if (end < 0) return payload;
  return payload.slice(end + 1);
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

// --- Punctuation: no ASS backslash-prefix on normal marks (comma, stops, quotes, parens, Hebrew)
const punctLatin =
  'Hi, world. Really? Yes! Note: one; two ("ok") \'fine\' (25/5) ו/או tail.';
const escLat = escapeAssTextLine(punctLatin);
assert.equal(escLat, punctLatin);
assert.ok(!escLat.includes("\\,"), "comma must not be \\,");
assert.ok(!escLat.includes("\\\\"), "no backslash doubling on content");

const punctHe =
  "שלום, מה שלומך? מצוין! הוא אמר: כן; בסוף. גרשיים ״ציטוט׳ גרש ׳א׳";
const escHe = escapeAssTextLine(punctHe);
assert.equal(escHe, punctHe);
assert.ok(!escHe.includes("\\"));

const punctTwo = joinAssLines(["שאלה: מה נשמע, חבר?", 'תשובה: הכל טוב; "מעולה".']);
assert.ok(punctTwo.includes("\\N"), "line break only");
assert.ok(!punctTwo.includes("\\,"));
assert.ok(punctTwo.includes(","), "comma visible in joined payload");
assert.ok(punctTwo.includes("?"), "question mark preserved");
assert.ok(punctTwo.includes("!") || punctTwo.includes("."), "terminal punctuation preserved");

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
  const payload = extractOurDialogueCaptionPayload(dl);
  assert.ok(payload.length > 0, "dialogue payload");
  const body = stripLeadingAssOverride(payload);
  assert.ok(!body.includes("\\\\N"), `ASS body: ${body}`);
  assert.ok(!/\s\/n(?=\s|$)/iu.test(body), "raw /N leak");
}

const assPunct = segmentsToAssContent(
  [
    {
      startSec: 0,
      endSec: 3,
      text: 'בדיקה: א, ב. ג? ד! ה: ו; ז"ח (י) 25/5 ו/או ״ט׳',
    } satisfies TranscriptSegment,
  ],
  { ...baseOpts, title: "punct" },
);
const punctDl = dialogueLines(assPunct)[0];
assert.ok(punctDl, "one dialogue line");
const punctPayload = extractOurDialogueCaptionPayload(punctDl!);
const punctBody = stripLeadingAssOverride(punctPayload);
assert.ok(punctBody.includes(","), "comma in burned caption");
assert.ok(punctBody.includes("."), "period");
assert.ok(punctBody.includes("?"), "question");
assert.ok(punctBody.includes("!"), "exclamation");
assert.ok(punctBody.includes(":"), "colon");
assert.ok(punctBody.includes(";"), "semicolon");
assert.ok(punctBody.includes('"'), "ASCII quote");
assert.ok(punctBody.includes("(") && punctBody.includes(")"), "parens");
assert.ok(punctBody.includes("25/5") && punctBody.includes("ו/או"), "slashes in words");
assert.ok(!punctBody.includes("\\,"), "no comma escape in caption text");
console.log("diag:ass-captions — ok");
