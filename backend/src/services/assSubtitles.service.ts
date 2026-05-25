import type { CaptionsBurnInV1Resolved } from "../modules/edit/edit.types";
import type { TranscriptSegment } from "./transcription.service";

/** ASS line break (two chars backslash+N in file). */
const LB = "\\N";

/** Logical script grid — ffmpeg/libass scales to output video. */
const PLAY_RES_X = 960;
const PLAY_RES_Y = 540;

const FONT_SIZES: Record<CaptionsBurnInV1Resolved["fontSize"], number> = {
  small: 28,
  medium: 34,
  large: 42,
};

const MAX_CHARS_PER_LINE: Record<CaptionsBurnInV1Resolved["fontSize"], number> = {
  small: 36,
  medium: 30,
  large: 24,
};

const MARGIN_H = 48;
/** Safe vertical margin from top/bottom (script pixels). */
const MARGIN_V = 82;

export type SegmentsToAssOpts = CaptionsBurnInV1Resolved & {
  readonly title?: string;
};

/**
 * Produce a playable ASS subtitle file for ffmpeg burn-in.
 * Applies V1.5 styling, wrapping (~2 lines / event), and duration-weighted chunking.
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
WrapStyle: 0
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
    for (const ev of events) {
      if (ev.text.length === 0) continue;
      lines.push(`Dialogue: 0,${toAssTs(ev.startSec)},${toAssTs(ev.endSec)},Default,,0,0,0,,${ev.text}`);
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
  /** ASS: OutlineColour BB GGRR, BackColour for BorderStyle 3 box */
  const outlineBlack = "&H00101010";
  let outline = 2.75;
  let shadow = 1.85;
  let bold = 0;
  let borderStyle = 1;
  let back = "&HC0000000";

  switch (p.style) {
    case "clean":
      outline = 2.65;
      shadow = 1.65;
      bold = 0;
      borderStyle = 1;
      back = "&H00000000";
      break;
    case "bold":
      outline = 4.25;
      shadow = 2.95;
      bold = 1;
      borderStyle = 1;
      back = "&H00000000";
      break;
    case "dark_box":
      outline = 1.85;
      shadow = 0.95;
      bold = 0;
      borderStyle = 3;
      back = "&H98303030"; /** semi-transparent dark panel */
      break;
    default:
      break;
  }

  const scaleX = p.style === "bold" ? 101 : 100;
  const scaleY = p.style === "bold" ? 101 : 100;
  /** Name, Fontname, Fontsize, Primary, Secondary, OutlineColour, BackColour, Bold, ... */
  return `Style: Default,Arial,${p.fontSize},${p.primaryColour},${secondaryOrPlaceholder()},${outlineBlack},${back},${bold},0,0,0,${scaleX},${scaleY},0,0,${borderStyle},${outline.toFixed(2)},${shadow.toFixed(2)},${p.alignment},${MARGIN_H},${MARGIN_H},${MARGIN_V},1`;
}

/** Secondary unused for burn-in; keep opaque magenta placeholder per spec habit */
function secondaryOrPlaceholder(): string {
  return "&H000000FF";
}

type DialogueEvent = { startSec: number; endSec: number; text: string };

/** Split one transcript segment into wrapped, time-weighted subtitle events (max 2 lines each). */
function segmentToDialogueEvents(seg: TranscriptSegment, maxCharsPerLine: number): DialogueEvent[] {
  const plain = preprocessCaptionPlain(seg.text);
  if (!plain.length) return [];

  const words = plain.split(/\s+/).filter((w) => w.length > 0);
  if (words.length === 0) return [];

  const lines = greedyWordWrap(words, maxCharsPerLine);
  /** Up to 2 lines per ASS event */
  const chunks: string[] = [];
  for (let i = 0; i < lines.length; i += 2) {
    const a = lines[i] ?? "";
    const b = lines[i + 1] ?? "";
    const body = b.length ? `${a}${LB}${b}` : a;
    chunks.push(sanitizeWrappedBody(body));
  }
  if (chunks.length === 0) return [];

  const dur = Math.max(0.12, seg.endSec - seg.startSec);
  const k = chunks.length;
  const slice = dur / k;
  const events: DialogueEvent[] = [];
  for (let i = 0; i < k; i++) {
    const t0 = seg.startSec + i * slice;
    const rawEnd = i === k - 1 ? seg.endSec : seg.startSec + (i + 1) * slice;
    const endSec = Math.min(seg.endSec, Math.max(t0 + 0.06, rawEnd));
    events.push({ startSec: t0, endSec, text: chunks[i]! });
  }
  if (events.length) events[events.length - 1]!.endSec = seg.endSec;
  /** Non-overlap */
  for (let i = 1; i < events.length; i++) {
    const prev = events[i - 1]!;
    const curr = events[i]!;
    if (prev.endSec > curr.startSec) prev.endSec = curr.startSec;
  }
  return events;
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

  const hardSplitUnits = (s: string, maxUnits: number): string[] => {
    if ([...s].length <= maxUnits) return [s];
    const chunks: string[] = [];
    for (let i = 0; i < s.length; ) {
      const slice = [...s.slice(i)].slice(0, maxUnits).join("");
      chunks.push(slice);
      i += slice.length || 1;
    }
    return chunks;
  };

  const lineCharLen = (s: string): number => [...s].length;

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
        /** Long token may still exceed → force own line flush */
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

/** Escape for ASS Dialogue text after line breaks are fixed. */
function sanitizeWrappedBody(body: string): string {
  let t = body;
  t = t.replace(/\\/g, "\\\\");
  t = t.replace(/\n/g, LB);
  t = t.replace(/\r/g, "");
  t = t.replace(/,/g, "\\,");
  t = t.replace(/\{/g, "\\{").replace(/\}/g, "\\}");
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
