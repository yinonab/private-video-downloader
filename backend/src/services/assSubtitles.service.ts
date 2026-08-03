import type { CaptionsBurnInV1Resolved } from "../modules/edit/edit.types";
import type { TranscriptSegment } from "./transcription.service";
import { resolveCaptionOutline, type ResolvedCaptionOutline } from "./captionOutline.util";
import {
  CAPTION_MARGIN_H,
  CAPTION_MARGIN_V,
  CAPTION_MAX_CHARS_PER_LINE,
  CAPTION_PLAY_H,
  CAPTION_PLAY_W,
} from "./captionHighlight/dimensions";

/**
 * ASS dialogue hard line break token (literal backslash + N in subtitle file).
 * Must be inserted only after escaping each text line separately — never run full-body `\\` replace on strings containing this.
 */
const ASS_HARD_BREAK = "\\N";

/** Logical script grid — ffmpeg/libass scales to output video. */
const PLAY_RES_X = CAPTION_PLAY_W;
const PLAY_RES_Y = CAPTION_PLAY_H;

const FONT_SIZES: Record<CaptionsBurnInV1Resolved["fontSize"], number> = {
  extra_small: 16,
  small: 20,
  medium: 24,
  large: 30,
  x_large: 36,
  xx_large: 44,
  xxx_large: 54,
  mega: 66,
  ultra: 80,
};

const MARGIN_H = CAPTION_MARGIN_H;
/** Safe vertical margin from top/bottom (script pixels) — avoids edge-glued captions. */
const MARGIN_V = CAPTION_MARGIN_V;

/** Sub-event floor when splitting one Whisper segment across multiple Dialogue lines (smooth read, avoid flicker). */
const MIN_VISIBLE_CHUNK_DURATION_SEC = 0.85;

/** Fallback when adaptive wrap still yields tiny slices (parity with legacy floor). */
const MIN_CHUNK_DURATION_SEC = 0.16;

export type SegmentsToAssOpts = CaptionsBurnInV1Resolved & {
  readonly title?: string;
};

export type SegmentsToAssMeta = {
  ass: string;
  wordCount: number;
  usedFallbackTiming: boolean;
};

/**
 * Produce a playable ASS subtitle file for ffmpeg burn-in.
 * Rendering fix 1.5.1: smaller font map, `\N` only between escaped lines (no visible backslashes).
 */
export function segmentsToAssContent(segments: TranscriptSegment[], opts: SegmentsToAssOpts): string {
  return segmentsToAssContentWithMeta(segments, opts).ass;
}

export function segmentsToAssContentWithMeta(segments: TranscriptSegment[], opts: SegmentsToAssOpts): SegmentsToAssMeta {
  const title = opts.title ?? "linkclip-caption";
  const fontSize = FONT_SIZES[opts.fontSize];
  const maxLen = CAPTION_MAX_CHARS_PER_LINE[opts.fontSize];
  const align = opts.position === "top" ? 8 : 2;
  const styleRow = buildDefaultStyleRow({
    fontSize,
    primaryColour: captionPrimaryAssColour(opts.color, opts.style),
    style: opts.style,
    color: opts.color,
    alignment: align,
    fontFamily: opts.fontFamily,
    outline: resolveCaptionOutline(opts),
  });

  const header = `[Script Info]
Title: ${title.replace(/[^\w\- ]+/g, "").slice(0, 80)}
ScriptType: v4.00+
PlayResX: ${PLAY_RES_X}
PlayResY: ${PLAY_RES_Y}
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
${styleRow}

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
`;

  const lines: string[] = [header.trimEnd()];
  let wordCount = 0;
  let usedFallbackTiming = false;
  for (const s of segments) {
    const out = segmentToDialogueEvents(s, maxLen, opts);
    const events = out.events;
    wordCount += out.wordCount;
    usedFallbackTiming = usedFallbackTiming || out.usedFallbackTiming;
    const { x: px, y: py, an: pan } = computeDialoguePos(opts);
    const posPre = dialoguePosOverridePrefix(pan, px, py);
    for (const ev of events) {
      if (ev.text.length === 0) continue;
      lines.push(
        `Dialogue: 0,${toAssTs(ev.startSec)},${toAssTs(ev.endSec)},Default,,0,0,0,,${posPre}${ev.text}`,
      );
    }
  }
  const body = `${lines.join("\n")}\n`;
  debugAssIntegrityLog(body);
  return { ass: body, wordCount, usedFallbackTiming };
}

function captionAssFontName(family: CaptionsBurnInV1Resolved["fontFamily"]): string {
  switch (family) {
    case "heebo":
      return "Heebo";
    case "rubik":
      return "Rubik";
    case "assistant":
      return "Assistant";
    case "noto_sans_hebrew":
      return "Noto Sans Hebrew";
    case "default":
    default:
      return "Noto Sans Hebrew";
  }
}

function captionPrimaryAssColour(
  color: CaptionsBurnInV1Resolved["color"],
  style: CaptionsBurnInV1Resolved["style"],
): string {
  if (style === "highlight_box") {
    return highlightBoxTextAssColour(color);
  }
  return accentAssColour(color);
}

/** Accent / main text colour (ASS BGR opaque). */
function accentAssColour(color: CaptionsBurnInV1Resolved["color"]): string {
  switch (color) {
    case "yellow":
      return "&H0066D9FF";
    case "purple":
      return "&H00F65C8B";
    case "pink":
      return "&H008A5CFF";
    case "mint":
      return "&H0099D334";
    case "white":
    default:
      return "&H00FFFFFF";
  }
}

function highlightBoxTextAssColour(color: CaptionsBurnInV1Resolved["color"]): string {
  switch (color) {
    case "yellow":
    case "mint":
    case "white":
    case "pink":
      return "&H00101010";
    case "purple":
    case "pink":
    default:
      return "&H00FFFFFF";
  }
}

function highlightBoxBackAssColour(color: CaptionsBurnInV1Resolved["color"]): string {
  switch (color) {
    case "yellow":
      return "&HC066D9FF";
    case "purple":
      return "&HC0F65C8B";
    case "pink":
      return "&HC08A5CFF";
    case "mint":
      return "&HC099D334";
    case "white":
    default:
      return "&HC0FFFFFF";
  }
}

function buildDefaultStyleRow(p: {
  fontSize: number;
  primaryColour: string;
  style: CaptionsBurnInV1Resolved["style"];
  color: CaptionsBurnInV1Resolved["color"];
  alignment: number;
  fontFamily: CaptionsBurnInV1Resolved["fontFamily"];
  outline: ResolvedCaptionOutline;
}): string {
  let outlineColour = "&H00101010";
  let outline = 2.65;
  let shadow = 1.65;
  let bold = 0;
  let borderStyle = 1;
  let back = "&H00000000";
  let primary = p.primaryColour;

  switch (p.style) {
    case "clean":
      outline = 2.45;
      shadow = 1.45;
      bold = 0;
      borderStyle = 1;
      back = "&H00000000";
      break;
    case "clean_pro":
      outline = 2.55;
      shadow = 1.55;
      bold = 0;
      borderStyle = 1;
      back = "&H00000000";
      break;
    case "bold":
      outline = 3.85;
      shadow = 2.65;
      bold = 1;
      borderStyle = 1;
      back = "&H00000000";
      break;
    case "bold_social":
      outline = 4.25;
      shadow = 2.85;
      bold = 1;
      borderStyle = 1;
      back = "&H00000000";
      break;
    case "yellow_headline":
      outline = 4.45;
      shadow = 2.95;
      bold = 1;
      borderStyle = 1;
      back = "&H00000000";
      primary = accentAssColour("yellow");
      break;
    case "dark_box":
      outline = 1.65;
      shadow = 0.85;
      bold = 0;
      borderStyle = 3;
      back = "&H98303030";
      break;
    case "dark_bubble":
      outline = 1.45;
      shadow = 0.65;
      bold = 0;
      borderStyle = 3;
      back = "&HA0282828";
      primary = "&H00FFFFFF";
      break;
    case "highlight_box":
      outline = 0.85;
      shadow = 0.45;
      bold = 1;
      borderStyle = 3;
      back = highlightBoxBackAssColour(p.color);
      primary = highlightBoxTextAssColour(p.color);
      break;
    default:
      break;
  }

  const scaleX =
    p.style === "bold" || p.style === "bold_social" || p.style === "yellow_headline" ? 101 : 100;
  const scaleY = scaleX;
  const fontName = captionAssFontName(p.fontFamily);
  if (p.outline.enabled) {
    outlineColour = p.outline.assColour;
    outline = p.outline.assWidth;
  }
  return `Style: Default,${fontName},${p.fontSize},${primary},${secondaryOrPlaceholder()},${outlineColour},${back},${bold},0,0,0,${scaleX},${scaleY},0,0,${borderStyle},${outline.toFixed(2)},${shadow.toFixed(2)},${p.alignment},${MARGIN_H},${MARGIN_H},${MARGIN_V},1`;
}

function secondaryOrPlaceholder(): string {
  return "&H000000FF";
}

/**
 * ASS `\pos(x,y)` center anchor coordinates; `\an2` bottom-center, `\an8` top-center.
 * Commas inside override tags must be `\,` so Dialogue comma-splitting ignores them.
 */
function dialoguePosOverridePrefix(an: number, x: number, y: number): string {
  return `{\\an${an}\\pos(${Math.round(x)}\\,${Math.round(y)})}`;
}

/** Map API offsets (+Y = down on screen) onto PlayRes, clamp so lines stay usable on-screen. */
function computeDialoguePos(opts: CaptionsBurnInV1Resolved): { x: number; y: number; an: number } {
  const padX = 48;
  const ox = opts.offsetX;
  const oy = opts.offsetY;
  const halfW = PLAY_RES_X / 2;
  let x = Math.round(halfW + ox);
  x = Math.min(PLAY_RES_X - padX, Math.max(padX, x));

  if (opts.position === "top") {
    let yRaw = Math.round(MARGIN_V + oy);
    const yLo = 38;
    const yHi = Math.floor(PLAY_RES_Y * 0.46);
    yRaw = Math.min(yHi, Math.max(yLo, yRaw));
    return { x, y: yRaw, an: 8 };
  }

  let yRaw = Math.round(PLAY_RES_Y - MARGIN_V + oy);
  const yHi = PLAY_RES_Y - 38;
  const yLo = Math.ceil(PLAY_RES_Y * 0.54);
  yRaw = Math.min(yHi, Math.max(yLo, yRaw));
  return { x, y: yRaw, an: 2 };
}

type DialogueEvent = { startSec: number; endSec: number; text: string };
type SegmentEventsOut = {
  events: DialogueEvent[];
  wordCount: number;
  usedFallbackTiming: boolean;
};

/**
 * Strip Whisper/transcription artefacts that otherwise render as slashes or bogus line breaks.
 * Order: NFC → strip override braces → newline tokens → bogus `\\…N` / `/N` → stray backslashes.
 * Does **not** remove normal "/" (e.g. `25/5`, `ו/או`).
 */
export function normalizeCaptionText(raw: string): string {
  let t = raw.normalize("NFC");
  /* Physical newlines → space before word split */
  t = t.replace(/\r\n|\r|\n/g, " ");
  t = t.replace(/\s+/g, " ").trim();
  t = t.replace(/\{[^}]*\}/g, "");

  /** Literal backslash sequences + N (`\N`, `\\N`, …) */
  t = t.replace(/\\+N/gi, " ");

  /** Mistyped `/n`/`/N` as line marker (Whitespace-delimited keeps `25/5`, `ו/או`). */
  t = t.replace(/\s+\/n(?=\s|$)/gi, " ");
  t = t.replace(/^\s*\/n(?=\s|$)/gi, " ");

  /** Isolated backslash glitch (standalone token) → removed */
  t = t.replace(/(?:^|\s)\\+(?=($|\s))/g, " ");

  /** Remaining backslashes (transcription artefacts) */
  t = t.replace(/\\/g, "");

  return t.replace(/\s+/g, " ").trim();
}

/**
 * Prepare one logical caption line for ASS Dialogue Text.
 * Leaves normal punctuation as-is (, . ? ! : ; " ' ( ) …); does **not** use `\,` or other ASS “punctuation escapes”.
 *
 * Neutralizes ASS override syntax only: `{...}` blocks removed in `normalizeCaptionText`, then orphan `{` /
 * `}` stripped. Transcript backslashes stripped in normalization — no line-level `\\` doubling.
 *
 * Intended `\N` is inserted only via `joinAssLines` — never escaped again after join.
 */
export function escapeAssTextLine(raw: string): string {
  let t = normalizeCaptionText(raw).replace(/\{[^}]*\}/g, "");
  t = t.replace(/\{|\}/g, "");
  t = t.replace(/\r/g, "");
  const out = t.trim();
  return out.length === 0 ? "" : out;
}

/** Concatenate escaped lines using one ASS hard break `\N` in the emitted file — do not escape result. */
export function joinAssLines(lines: readonly string[]): string {
  const parts = lines.map((ln) => escapeAssTextLine(ln)).filter((s) => s.length > 0);
  return parts.join(ASS_HARD_BREAK);
}

/** Count Dialogue rows in ASS body — for diagnostics only */
function countAssDialogueLines(assBody: string): number {
  let n = 0;
  for (const line of assBody.split("\n")) {
    if (/^Dialogue:/i.test(line.trimStart())) n += 1;
  }
  return n;
}

/** No transcript / filenames — validates structural markers only (`LINKCLIP_ASS_DEBUG=true`). */
function debugAssIntegrityLog(assBody: string): void {
  if ((process.env.LINKCLIP_ASS_DEBUG ?? "").trim() !== "true") return;
  const dialogueCount = countAssDialogueLines(assBody);
  /* In ASS file: `\\\N` = two backslashes + N (often visible as glitch) */
  const hasDoubleEscapedLb = assBody.includes("\\\\N") || /\x5c\x5cn/i.test(assBody);
  const hasSuspMarkers = /\s\\n\s|\\{3,}\s*n/i.test(assBody);
  console.info(
    `caption ASS validation: events=${dialogueCount}, hasDoubleEscapedLineBreak=${hasDoubleEscapedLb}, suspiciousSlashMarkers=${hasSuspMarkers}`,
  );
}

/**
 * Whisper segment span is preserved; Dialogue slices are subdivisions of [start,end) only — no timestamp shift.
 */
function segmentToDialogueEvents(
  seg: TranscriptSegment,
  maxCharsPerLine: number,
  opts: SegmentsToAssOpts
): SegmentEventsOut {
  const plain = normalizeCaptionText(seg.text);
  if (!plain.length) return { events: [], wordCount: 0, usedFallbackTiming: false };

  const rawStart = seg.startSec;
  const rawEnd = seg.endSec;
  let start = Number.isFinite(rawStart) && rawStart >= 0 ? rawStart : 0;
  let end = Number.isFinite(rawEnd) ? rawEnd : start + MIN_CHUNK_DURATION_SEC * 8;
  if (!(end > start)) end = start + Math.max(MIN_CHUNK_DURATION_SEC, 0.2);
  const dur = end - start;

  /** Prefer ≤2 wrapping lines → one event; widen budget only enough to honour min chunk duration. */
  let maxChars = Math.max(8, Math.floor(maxCharsPerLine));

  interface BuildResult {
    readonly wrappedLines: string[];
    readonly chunks: string[];
  }

  const buildChunks = (): BuildResult => {
    const words = plain.split(/\s+/).filter((w) => w.length > 0);
    const wrappedLines = greedyWordWrap(words, maxChars);
    const chunks: string[] = [];
    for (let i = 0; i < wrappedLines.length; i += 2) {
      const line1 = wrappedLines[i] ?? "";
      const line2 = wrappedLines[i + 1];
      const dlg = joinAssLines(line2?.trim().length ? [line1, line2] : [line1]);
      if (dlg.length > 0) chunks.push(dlg);
    }
    return { wrappedLines, chunks };
  };

  let { wrappedLines, chunks } = buildChunks();
  while (chunks.length > 1) {
    const per = dur / chunks.length;
    if (per >= MIN_VISIBLE_CHUNK_DURATION_SEC || maxChars >= 48 + maxCharsPerLine) break;
    maxChars += 2;
    const next = buildChunks();
    wrappedLines = next.wrappedLines;
    chunks = next.chunks;
  }

  /** If still forced to split densely, widen until each slice ≥ floor or chunks cap at 4× budget */
  while (chunks.length > 1 && dur / chunks.length < MIN_VISIBLE_CHUNK_DURATION_SEC && maxChars < 96) {
    maxChars += 2;
    const next = buildChunks();
    wrappedLines = next.wrappedLines;
    chunks = next.chunks;
  }

  if (chunks.length === 0) return { events: [], wordCount: 0, usedFallbackTiming: false };

  const k = chunks.length;
  const events: DialogueEvent[] = [];
  for (let i = 0; i < k; i++) {
    const t0 = start + (dur * i) / k;
    const t1 = i === k - 1 ? end : start + (dur * (i + 1)) / k;
    events.push({ startSec: t0, endSec: t1, text: chunks[i]! });
  }

  if (opts.wordHighlight === "none") {
    return { events, wordCount: 0, usedFallbackTiming: false };
  }

  const highlight: DialogueEvent[] = [];
  let wordsUsed = 0;
  let usedFallback = false;
  for (const ev of events) {
    const sliced = buildHighlightedEventsForChunk(seg, ev, opts.wordHighlight, opts.color);
    wordsUsed += sliced.wordCount;
    usedFallback = usedFallback || sliced.usedFallbackTiming;
    highlight.push(...sliced.events);
  }

  void wrappedLines;
  return { events: highlight, wordCount: wordsUsed, usedFallbackTiming: usedFallback };
}

/** For script-based regression checks only — not a public API guarantee. */
export function segmentToDialogueEventsForTests(
  seg: TranscriptSegment,
  maxCharsPerLine: number,
): DialogueEvent[] {
  return segmentToDialogueEvents(seg, maxCharsPerLine, {
    mode: "auto",
    language: "auto",
    burnIn: true,
    style: "clean",
    fontSize: "medium",
    fontFamily: "default",
    position: "bottom",
    color: "white",
    wordHighlight: "none",
    offsetX: 0,
    offsetY: 0,
  }).events;
}

function buildHighlightedEventsForChunk(
  seg: TranscriptSegment,
  ev: DialogueEvent,
  mode: CaptionsBurnInV1Resolved["wordHighlight"],
  color: CaptionsBurnInV1Resolved["color"]
): { events: DialogueEvent[]; wordCount: number; usedFallbackTiming: boolean } {
  const words = ev.text.split(ASS_HARD_BREAK).flatMap((ln) => ln.split(/\s+/).map((w) => normalizeCaptionText(w)).filter(Boolean));
  if (words.length < 2) return { events: [ev], wordCount: words.length, usedFallbackTiming: false };
  const cues = resolveWordCues(seg, words, ev.startSec, ev.endSec);
  if (!cues.length) return { events: [ev], wordCount: 0, usedFallbackTiming: true };
  const out: DialogueEvent[] = [];
  for (let i = 0; i < cues.length; i++) {
    const cue = cues[i]!;
    const next = cues[i + 1];
    const t0 = Math.max(ev.startSec, cue.startSec);
    const t1 = Math.min(ev.endSec, next ? next.startSec : cue.endSec);
    if (!(t1 > t0 + 1e-4)) continue;
    out.push({
      startSec: t0,
      endSec: t1,
      text: applyWordHighlight(ev.text, cue.word, mode, color),
    });
  }
  if (!out.length) return { events: [ev], wordCount: cues.length, usedFallbackTiming: true };
  return { events: out, wordCount: cues.length, usedFallbackTiming: Boolean(cues.usedFallback) };
}

function resolveWordCues(
  seg: TranscriptSegment,
  displayWords: readonly string[],
  sliceStart: number,
  sliceEnd: number
): (readonly { startSec: number; endSec: number; word: string }[] & { usedFallback?: boolean }) {
  const wordsRaw = Array.isArray(seg.words) ? seg.words : undefined;
  const fromPayload = wordsRaw
    ?.map((w) => ({
      startSec: Number.isFinite(w.startSec) ? w.startSec : Number.NaN,
      endSec: Number.isFinite(w.endSec) ? w.endSec : Number.NaN,
      word: normalizeCaptionText(w.text),
    }))
    .filter((w) => Number.isFinite(w.startSec) && Number.isFinite(w.endSec) && w.endSec > w.startSec && w.word.length > 0);
  const payloadWords = fromPayload && fromPayload.length ? fromPayload : undefined;
  const normalizedDisplay = displayWords.map((w) => normalizeCaptionText(w)).filter(Boolean);
  if (!normalizedDisplay.length) return [] as readonly { startSec: number; endSec: number; word: string }[];
  if (!payloadWords?.length) {
    return Object.assign(approximateWords(normalizedDisplay, sliceStart, sliceEnd), { usedFallback: true });
  }
  const payloadNormalized = payloadWords.map((w) => w.word);
  const canReuse = payloadNormalized.length === normalizedDisplay.length && payloadNormalized.every((w, i) => w === normalizedDisplay[i]);
  if (!canReuse) {
    return Object.assign(approximateWords(normalizedDisplay, sliceStart, sliceEnd), { usedFallback: true });
  }
  const minStart = payloadWords[0]!.startSec;
  const maxEnd = payloadWords[payloadWords.length - 1]!.endSec;
  const srcDur = Math.max(1e-4, maxEnd - minStart);
  const dstDur = Math.max(1e-4, seg.endSec - seg.startSec);
  const scaled = payloadWords.map((w) => {
    const stNorm = (w.startSec - minStart) / srcDur;
    const enNorm = (w.endSec - minStart) / srcDur;
    const st = seg.startSec + stNorm * dstDur;
    const en = seg.startSec + enNorm * dstDur;
    return {
      startSec: Math.max(seg.startSec, Math.min(seg.endSec, st)),
      endSec: Math.max(seg.startSec, Math.min(seg.endSec, en)),
      word: w.word,
    };
  });
  return Object.assign(
    scaled
      .map((w) => ({
        startSec: Math.max(sliceStart, Math.min(sliceEnd, w.startSec)),
        endSec: Math.max(sliceStart, Math.min(sliceEnd, w.endSec)),
        word: w.word,
      }))
      .filter((w) => w.endSec > w.startSec + 1e-4),
    { usedFallback: false }
  );
}

function approximateWords(
  words: readonly string[],
  startSec: number,
  endSec: number
): readonly { startSec: number; endSec: number; word: string }[] {
  const dur = Math.max(1e-4, endSec - startSec);
  return words.map((word, i) => ({
    startSec: startSec + (dur * i) / words.length,
    endSec: i === words.length - 1 ? endSec : startSec + (dur * (i + 1)) / words.length,
    word,
  }));
}

function applyWordHighlight(
  chunkText: string,
  targetWord: string,
  mode: CaptionsBurnInV1Resolved["wordHighlight"],
  color: CaptionsBurnInV1Resolved["color"]
): string {
  const escaped = escapeRegExp(targetWord);
  const rx = new RegExp(`(^|\\s)(${escaped})(?=\\s|$)`, "u");
  const accent = accentAssColour(color);
  const boxBack = highlightBoxBackAssColour(color);
  const boxText = highlightBoxTextAssColour(color);
  return chunkText.replace(rx, (_m, lead: string, w: string) => {
    if (mode === "box") {
      return `${lead}{\\bord1.8\\shad0.7\\1c${boxText}\\3c&H00101010\\4c${boxBack}}${w}{\\r}`;
    }
    return `${lead}{\\1c${accent}}${w}{\\r}`;
  });
}

function escapeRegExp(input: string): string {
  return input.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Greedy word wrap → lines (respect word boundaries when possible). */
function greedyWordWrap(words: readonly string[], maxChars: number): string[] {
  const linesOut: string[] = [];
  let cur = "";

  const flushLine = (): void => {
    const trimmed = cur.trim();
    if (trimmed.length) linesOut.push(trimmed);
    cur = "";
  };

  const pushWord = (w: string): void => {
    if (cur.length === 0) cur = w;
    else cur = `${cur} ${w}`;
  };

  const unitsOf = (s: string): string[] => [...s];

  const hardSplitUnits = (s: string, maxUnits: number): string[] => {
    const u = unitsOf(s);
    if (u.length <= maxUnits) return [s];
    const chunks: string[] = [];
    for (let i = 0; i < u.length; i += maxUnits) chunks.push(u.slice(i, i + maxUnits).join(""));
    return chunks;
  };

  const lineCharLen = (s: string): number => unitsOf(s).length;

  for (const w of words) {
    if (lineCharLen(w) > maxChars) {
      flushLine();
      const parts = hardSplitUnits(w, maxChars);
      for (let p = 0; p < parts.length; p++) {
        const piece = parts[p]!;
        if (lineCharLen(cur) === 0) pushWord(piece);
        else if (lineCharLen(cur) + 1 + lineCharLen(piece) <= maxChars) pushWord(piece);
        else {
          flushLine();
          pushWord(piece);
        }
        if (lineCharLen(cur) >= maxChars) flushLine();
      }
      continue;
    }

    if (cur.length === 0 || lineCharLen(cur) + 1 + lineCharLen(w) <= maxChars) pushWord(w);
    else {
      flushLine();
      pushWord(w);
    }
  }
  flushLine();
  return linesOut;
}

/** Convert fractional seconds → `H:MM:SS.cc` ASS event time base. */
function toAssTs(sec: number): string {
  if (!Number.isFinite(sec) || sec < 0) sec = 0;
  sec = Math.min(sec, 99 * 3600);
  const h = Math.floor(sec / 3600);
  let r = sec - h * 3600;
  const m = Math.floor(r / 60);
  r -= m * 60;
  const s = Math.floor(r);
  const cs = Math.floor((r - s) * 100 + 0.5); /* centiseconds */
  const csClamp = cs >= 100 ? 99 : cs;
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}.${String(csClamp).padStart(2, "0")}`;
}
