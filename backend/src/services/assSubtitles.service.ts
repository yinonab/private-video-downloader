import type { CaptionsBurnInV1Resolved } from "../modules/edit/edit.types";
import type { TranscriptSegment } from "./transcription.service";

/**
 * ASS dialogue hard line break token (literal backslash + N in subtitle file).
 * Must be inserted only after escaping each text line separately — never run full-body `\\` replace on strings containing this.
 */
const ASS_HARD_BREAK = "\\N";

/** Logical script grid — ffmpeg/libass scales to output video. */
const PLAY_RES_X = 960;
const PLAY_RES_Y = 540;

const FONT_SIZES: Record<CaptionsBurnInV1Resolved["fontSize"], number> = {
  extra_small: 16,
  small: 20,
  medium: 24,
  large: 30,
};

/** Per-line grapheme-ish limits — keeps ≤2 rendered lines via manual wrap (`WrapStyle: 2`). */
const MAX_CHARS_PER_LINE: Record<CaptionsBurnInV1Resolved["fontSize"], number> = {
  extra_small: 32,
  small: 28,
  medium: 24,
  large: 20,
};

const MARGIN_H = 52;
/** Safe vertical margin from top/bottom (script pixels) — avoids edge-glued captions. */
const MARGIN_V = 96;

const MIN_CHUNK_DURATION_SEC = 0.16;

export type SegmentsToAssOpts = CaptionsBurnInV1Resolved & {
  readonly title?: string;
};

/**
 * Produce a playable ASS subtitle file for ffmpeg burn-in.
 * Rendering fix 1.5.1: smaller font map, `\N` only between escaped lines (no visible backslashes).
 */
export function segmentsToAssContent(segments: TranscriptSegment[], opts: SegmentsToAssOpts): string {
  const title = opts.title ?? "linkclip-caption";
  const fontSize = FONT_SIZES[opts.fontSize];
  const maxLen = MAX_CHARS_PER_LINE[opts.fontSize];
  const align = opts.position === "top" ? 8 : 2;
  const primaryColour = captionPrimaryAssColour(opts.color);
  const styleRow = buildDefaultStyleRow({
    fontSize,
    primaryColour,
    style: opts.style,
    alignment: align,
  });

  const header = `[Script Info]
Title: ${title.replace(/[^\w\- ]+/g, "").slice(0, 80)}
ScriptType: v4.00+
PlayResX: ${PLAY_RES_X}
PlayResY: ${PLAY_RES_Y}
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
${styleRow}

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
`;

  const lines: string[] = [header.trimEnd()];
    for (const s of segments) {
    const events = segmentToDialogueEvents(s, maxLen);
    const { x: px, y: py, an: pan } = computeDialoguePos(opts);
    const posPre = dialoguePosOverridePrefix(pan, px, py);
    for (const ev of events) {
      if (ev.text.length === 0) continue;
      lines.push(
        `Dialogue: 0,${toAssTs(ev.startSec)},${toAssTs(ev.endSec)},Default,,0,0,0,,${posPre}${ev.text}`,
      );
    }
  }
  return `${lines.join("\n")}\n`;
}

function captionPrimaryAssColour(color: CaptionsBurnInV1Resolved["color"]): string {
  if (color === "yellow") return "&H0066D9FF"; /** ~#FFD966 BGR opaque */
  return "&H00FFFFFF";
}

function buildDefaultStyleRow(p: {
  fontSize: number;
  primaryColour: string;
  style: CaptionsBurnInV1Resolved["style"];
  alignment: number;
}): string {
  const outlineBlack = "&H00101010";
  let outline = 2.65;
  let shadow = 1.65;
  let bold = 0;
  let borderStyle = 1;
  let back = "&H00000000";

  switch (p.style) {
    case "clean":
      outline = 2.45;
      shadow = 1.45;
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
    case "dark_box":
      outline = 1.65;
      shadow = 0.85;
      bold = 0;
      borderStyle = 3;
      back = "&H98303030";
      break;
    default:
      break;
  }

  const scaleX = p.style === "bold" ? 101 : 100;
  const scaleY = p.style === "bold" ? 101 : 100;
  return `Style: Default,Arial,${p.fontSize},${p.primaryColour},${secondaryOrPlaceholder()},${outlineBlack},${back},${bold},0,0,0,${scaleX},${scaleY},0,0,${borderStyle},${outline.toFixed(2)},${shadow.toFixed(2)},${p.alignment},${MARGIN_H},${MARGIN_H},${MARGIN_V},1`;
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

/** Max 2 lines per event; overflow → chunked events across segment time. */
function segmentToDialogueEvents(seg: TranscriptSegment, maxCharsPerLine: number): DialogueEvent[] {
  const plain = preprocessCaptionPlain(seg.text);
  if (!plain.length) return [];

  const words = plain.split(/\s+/).filter((w) => w.length > 0);
  if (words.length === 0) return [];

  const wrappedLines = greedyWordWrap(words, maxCharsPerLine);
  const chunks: string[] = [];

  for (let i = 0; i < wrappedLines.length; i += 2) {
    const line1 = wrappedLines[i] ?? "";
    const line2 = wrappedLines[i + 1];
    const dlg = assembleTwoLineAssDialogue(line1, line2);
    if (dlg.length === 0) continue;
    chunks.push(dlg);
  }
  if (chunks.length === 0) return [];

  /** Partition [start,end) into k contiguous slices — no overlaps */
  const rawStart = seg.startSec;
  const rawEnd = seg.endSec;
  let start = Number.isFinite(rawStart) && rawStart >= 0 ? rawStart : 0;
  let end = Number.isFinite(rawEnd) ? rawEnd : start + MIN_CHUNK_DURATION_SEC * 8;
  if (!(end > start)) end = start + Math.max(MIN_CHUNK_DURATION_SEC, 0.2);

  const dur = end - start;
  const k = chunks.length;
  const events: DialogueEvent[] = [];
  for (let i = 0; i < k; i++) {
    const t0 = start + (dur * i) / k;
    const t1 = i === k - 1 ? end : start + (dur * (i + 1)) / k;
    events.push({ startSec: t0, endSec: t1, text: chunks[i]! });
  }
  return events;
}

/** Escape one logical line for ASS Dialogue (no `\N`). */
function escapeAssDialogueFragment(raw: string): string {
  let t = raw.normalize("NFC").trim();
  t = t.replace(/\{[^}]*\}/g, "");
  t = t.replace(/\r/g, "");
  /** Literal backslashes in subtitle text → doubled for ASS field */
  t = t.replace(/\\/g, "\\\\");
  t = t.replace(/,/g, "\\,");
  t = t.replace(/\{/g, "\\{").replace(/\}/g, "\\}");
  return t;
}

/**
 * Build Dialogue text: up to **2** ASS lines separated by verbatim `\N` (not escaped further).
 */
function assembleTwoLineAssDialogue(line1Raw: string, line2Raw: string | undefined): string {
  const a = escapeAssDialogueFragment(line1Raw);
  if (!a) return "";
  if (line2Raw == null || line2Raw.trim() === "") return a;
  const b = escapeAssDialogueFragment(line2Raw);
  return b ? `${a}${ASS_HARD_BREAK}${b}` : a;
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

function preprocessCaptionPlain(raw: string): string {
  let t = raw.normalize("NFC").replace(/\s+/g, " ").trim();
  t = t.replace(/\{[^}]*\}/g, "");
  return t;
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
