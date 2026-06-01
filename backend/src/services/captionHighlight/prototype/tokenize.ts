import type { CaptionToken } from "./types";

/** NFC + collapse whitespace; preserve punctuation attached to tokens (no ASS escapes). */
export function normalizePoCText(raw: string): string {
  return raw.normalize("NFC").replace(/\s+/g, " ").trim();
}

/** Split on whitespace; each token keeps trailing punctuation from Whisper/draft style. */
export function tokenizeCaptionText(raw: string): CaptionToken[] {
  const plain = normalizePoCText(raw);
  if (!plain.length) return [];
  return plain
    .split(/\s+/)
    .filter((w) => w.length > 0)
    .map((text, index) => ({ index, text }));
}

const HEBREW_RX = /[\u0590-\u05FF]/;

export function resolveTextDirection(
  text: string,
  direction: "auto" | "rtl" | "ltr",
): "rtl" | "ltr" {
  if (direction === "rtl" || direction === "ltr") return direction;
  return HEBREW_RX.test(text) ? "rtl" : "ltr";
}

/** Evenly spread [0..n-1] across duration — PoC stand-in for missing word timestamps. */
export function approximateActiveIndices(tokenCount: number): number[] {
  if (tokenCount <= 0) return [];
  return Array.from({ length: tokenCount }, (_, i) => i);
}
