import type { CaptionToken } from "./types";

/** NFC + collapse whitespace; preserve punctuation on tokens. */
export function normalizeCaptionText(raw: string): string {
  return raw.normalize("NFC").replace(/\s+/g, " ").trim();
}

const LEADING_PUNCT_RX = /^[\(\[\{"'«„״׳]+/u;
const TRAILING_PUNCT_RX = /[\.,:;!?…'\)"»""''״׳]+$/u;
const HAS_LETTER_OR_DIGIT_RX = /[\p{L}\p{N}]/u;

function splitTokenCluster(word: string, index: number): CaptionToken {
  const fullText = word;
  let core = word;
  let leadingPunctuation: string | undefined;
  let trailingPunctuation: string | undefined;

  const lead = core.match(LEADING_PUNCT_RX);
  if (lead?.[0]) {
    leadingPunctuation = lead[0];
    core = core.slice(leadingPunctuation.length);
  }

  const trail = core.match(TRAILING_PUNCT_RX);
  if (trail?.[0]) {
    trailingPunctuation = trail[0];
    core = core.slice(0, -trailingPunctuation.length);
  }

  const coreText = core.length > 0 ? core : fullText;
  const isWord = HAS_LETTER_OR_DIGIT_RX.test(coreText);

  return {
    index,
    text: fullText,
    fullText,
    coreText,
    ...(leadingPunctuation ? { leadingPunctuation } : {}),
    ...(trailingPunctuation ? { trailingPunctuation } : {}),
    isWord,
  };
}

/** Whitespace-split tokens; punctuation stays attached to each display cluster. */
export function tokenizeCaptionText(raw: string): CaptionToken[] {
  const plain = normalizeCaptionText(raw);
  if (!plain.length) return [];
  return plain
    .split(/\s+/)
    .filter((w) => w.length > 0)
    .map((word, index) => splitTokenCluster(word, index));
}

/** Text used for canvas measure/layout/draw — always the full display cluster. */
export function captionTokenDisplayText(token: CaptionToken): string {
  return token.fullText || token.text;
}

/** Match Whisper/payload word text to a display token (punctuation may differ). */
export function captionTokenMatchesWord(token: CaptionToken, wordNorm: string): boolean {
  if (!wordNorm) return false;
  if (wordNorm === token.fullText || wordNorm === token.text) return true;
  if (token.coreText && wordNorm === token.coreText) return true;
  if (token.trailingPunctuation && wordNorm === `${token.coreText}${token.trailingPunctuation}`) {
    return true;
  }
  if (token.leadingPunctuation && wordNorm === `${token.leadingPunctuation}${token.coreText}`) {
    return true;
  }
  return false;
}

const HEBREW_RX = /[\u0590-\u05FF]/;

export function resolveTextDirection(
  text: string,
  direction: "auto" | "rtl" | "ltr",
): "rtl" | "ltr" {
  if (direction === "rtl" || direction === "ltr") return direction;
  return HEBREW_RX.test(text) ? "rtl" : "ltr";
}
