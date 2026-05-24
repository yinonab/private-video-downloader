import type { TranscriptSegment } from "./transcription.service";

/** ASS line break */
const LB = "\\N";

/**
 * Produce a minimal playable ASS subtitle file (burn-in oriented).
 * V1 styling: bottom-center white text, opaque black outline, shadow for readability.
 */
export function segmentsToAssContent(segments: TranscriptSegment[], opts?: { title?: string }): string {
  const title = opts?.title ?? "linkclip-caption";
  const header = `[Script Info]
Title: ${title.replace(/[^\w\- ]+/g, "").slice(0, 80)}
ScriptType: v4.00+
PlayResX: 384
PlayResY: 288
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00101010,&H40000000,0,0,0,0,100,100,0,0,1,2.75,2,2,44,44,52,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
`;

  const lines: string[] = [header.trimEnd()];
  for (const s of segments) {
    const txt = sanitizeAssPlainTextForDialogue(s.text);
    if (txt.length === 0) continue;
    lines.push(`Dialogue: 0,${toAssTs(s.startSec)},${toAssTs(s.endSec)},Default,,0,0,0,,${txt}`);
  }
  return `${lines.join("\n")}\n`;
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
  /** Hours may exceed single digit — ASS allows multi-digit hour */
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}.${String(csClamp).padStart(2, "0")}`;
}

/**
 * Dialogue field text escapes (ASS override syntax).
 * Commas/newlines/dividers must not break Dialogue CSV layout.
 */
function sanitizeAssPlainTextForDialogue(raw: string): string {
  let t = raw.normalize("NFC").replace(/\s+/g, " ").trim();
  /** Remove ASS override blocks from raw Whisper output safely */
  t = t.replace(/\{[^}]*\}/g, "");
  /** Literal slash must double for ASS */
  t = t.replace(/\\/g, "\\\\");
  t = t.replace(/\n/g, LB);
  t = t.replace(/\r/g, "");
  /** Commas divide Dialogue CSV fields prior to Effect — escape them */
  t = t.replace(/,/g, "\\,");
  t = t.replace(/\{/g, "\\{").replace(/\}/g, "\\}");
  return t;
}
