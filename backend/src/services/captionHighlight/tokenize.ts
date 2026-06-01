import type { CaptionToken } from "./types";

/** NFC + collapse whitespace; preserve punctuation on tokens. */
export function normalizeCaptionText(raw: string): string {
  return raw.normalize("NFC").replace(/\s+/g, " ").trim();
}

export function tokenizeCaptionText(raw: string): CaptionToken[] {
  const plain = normalizeCaptionText(raw);
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
