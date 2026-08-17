import type { SKRSContext2D } from "@napi-rs/canvas";
import type { CaptionLayoutResult, CaptionLineLayout, CaptionToken, RenderPlateInput } from "./types";
import { captionFontCss } from "./fonts";
import type { CaptionCanvasSize } from "./dimensions";
import { captionBlockTopBase } from "./dimensions";
import { resolveTextDirection, tokenizeCaptionText, captionTokenDisplayText } from "./tokenize";

type MeasureCtx = Pick<SKRSContext2D, "font" | "measureText">;

/**
 * Highlight-canvas inter-word gap: natural U+0020 advance for the active ctx.font.
 * Single source of truth for measure + placement (ceil px; min 1).
 */
export function measureCaptionTokenGapPx(ctx: MeasureCtx): number {
  return Math.max(1, Math.ceil(ctx.measureText(" ").width));
}

function measureToken(ctx: MeasureCtx, token: CaptionToken): { width: number; ascent: number; descent: number } {
  const m = ctx.measureText(captionTokenDisplayText(token));
  const ascent = m.actualBoundingBoxAscent ?? m.emHeightAscent ?? 24;
  const descent = m.actualBoundingBoxDescent ?? m.emHeightDescent ?? 6;
  return { width: Math.ceil(m.width), ascent: Math.ceil(ascent), descent: Math.ceil(descent) };
}

function measureLineWidthPx(ctx: MeasureCtx, tokens: readonly CaptionToken[], tokenGapPx: number): number {
  if (!tokens.length) return 0;
  let w = 0;
  for (let i = 0; i < tokens.length; i++) {
    w += measureToken(ctx, tokens[i]!).width;
    if (i < tokens.length - 1) w += tokenGapPx;
  }
  return w;
}

/**
 * Tokenize forced logical lines with contiguous global token indices.
 * Does not choose new break points — `logicalLines` is the SoT output.
 */
function tokenizeForcedLines(
  logicalLines: readonly string[],
  maxLines: number,
): { tokens: CaptionToken[]; lineTokenGroups: CaptionToken[][] } {
  const lineTokenGroups: CaptionToken[][] = [];
  const tokens: CaptionToken[] = [];
  let nextIndex = 0;
  const capped = logicalLines.slice(0, Math.max(1, maxLines));
  for (const line of capped) {
    const local = tokenizeCaptionText(line);
    if (!local.length) continue;
    const remapped = local.map((t) => {
      const copy: CaptionToken = {
        ...t,
        index: nextIndex++,
      };
      return copy;
    });
    lineTokenGroups.push(remapped);
    tokens.push(...remapped);
  }
  return { tokens, lineTokenGroups };
}

function layoutLine(
  ctx: MeasureCtx,
  lineTokens: readonly CaptionToken[],
  direction: "rtl" | "ltr",
  lineY: number,
  lineHeight: number,
  originX: number,
  tokenGapPx: number,
): CaptionLineLayout {
  const metrics = lineTokens.map((t) => ({ token: t, ...measureToken(ctx, t) }));
  // Shared ascent for the line — text draw must use this, not per-glyph ascent
  // (per-glyph actualBoundingBoxAscent caused vertical "bobbing").
  const ascent = Math.max(1, ...metrics.map((m) => m.ascent));
  const baselineY = lineY + ascent;

  const boxes: {
    tokenIndex: number;
    x: number;
    y: number;
    width: number;
    height: number;
  }[] = [];

  if (direction === "ltr") {
    let cursor = originX;
    for (let i = 0; i < metrics.length; i++) {
      const m = metrics[i]!;
      boxes.push({
        tokenIndex: m.token.index,
        x: cursor,
        y: lineY,
        width: m.width,
        height: lineHeight,
      });
      cursor += m.width + (i < metrics.length - 1 ? tokenGapPx : 0);
    }
  } else {
    let cursor = originX;
    for (let i = 0; i < metrics.length; i++) {
      const m = metrics[i]!;
      cursor -= m.width;
      boxes.push({
        tokenIndex: m.token.index,
        x: cursor,
        y: lineY,
        width: m.width,
        height: lineHeight,
      });
      cursor -= i < metrics.length - 1 ? tokenGapPx : 0;
    }
  }

  return { tokens: lineTokens, boxes, y: lineY, lineHeight, ascent, baselineY };
}

export function layoutCaptionBlock(
  ctx: MeasureCtx,
  input: Pick<
    RenderPlateInput,
    | "text"
    | "lines"
    | "direction"
    | "fontSize"
    | "fontWeight"
    | "maxLines"
    | "canvasWidth"
    | "canvasHeight"
    | "position"
    | "maxLineWidthPx"
    | "lineGapPx"
    | "tokenGapPx"
  > & { offsetY?: number; canvas: CaptionCanvasSize },
  fontFamilyLabel: string,
): CaptionLayoutResult {
  const direction = resolveTextDirection(input.text, input.direction);
  ctx.font = captionFontCss(fontFamilyLabel, input.fontSize, input.fontWeight);
  // Authoritative gap from font space — ignore input.tokenGapPx (legacy field).
  const tokenGapPx = measureCaptionTokenGapPx(ctx);

  const { tokens, lineTokenGroups } = tokenizeForcedLines(input.lines, input.maxLines);

  // Overflow diagnostics only — do not invent new break points.
  for (let i = 0; i < lineTokenGroups.length; i++) {
    const group = lineTokenGroups[i]!;
    const w = measureLineWidthPx(ctx, group, tokenGapPx);
    if (w > input.maxLineWidthPx && process.env.LINKCLIP_CAPTION_WRAP_DEBUG === "true") {
      console.info(
        `caption layout overflow diag: line=${i} widthPx=${w} max=${input.maxLineWidthPx}`,
      );
    }
  }

  const lineHeights = lineTokenGroups.map((group) => {
    let maxH = 0;
    for (const t of group) {
      const m = measureToken(ctx, t);
      maxH = Math.max(maxH, m.ascent + m.descent);
    }
    return maxH || input.fontSize;
  });

  const blockHeight =
    lineHeights.reduce((a, b) => a + b, 0) + Math.max(0, lineTokenGroups.length - 1) * input.lineGapPx;

  const lineWidths = lineTokenGroups.map((group) => measureLineWidthPx(ctx, group, tokenGapPx));
  const blockWidth = Math.max(...lineWidths, 0);

  const blockTop = captionBlockTopBase(
    input.position,
    blockHeight,
    input.offsetY ?? 0,
    input.canvas,
  );
  const blockLeft = Math.round((input.canvas.width - blockWidth) / 2);

  const lines: CaptionLineLayout[] = [];
  let yCursor = blockTop;

  for (let li = 0; li < lineTokenGroups.length; li++) {
    const group = lineTokenGroups[li]!;
    const lh = lineHeights[li] ?? input.fontSize;
    const lw = lineWidths[li] ?? 0;
    const originX = direction === "ltr" ? blockLeft : blockLeft + lw;
    lines.push(layoutLine(ctx, group, direction, yCursor, lh, originX, tokenGapPx));
    yCursor += lh + input.lineGapPx;
  }

  return {
    tokens,
    lines,
    direction,
    blockWidth,
    blockHeight,
    blockLeft,
    blockTop,
    tokenGapPx,
  };
}
