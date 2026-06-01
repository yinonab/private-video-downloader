import type { SKRSContext2D } from "@napi-rs/canvas";
import type { CaptionLayoutResult, CaptionLineLayout, CaptionToken, RenderPlateInput } from "./types";
import { resolveTextDirection, tokenizeCaptionText } from "./tokenize";
import { poCFontCss } from "./fonts";

type MeasureCtx = Pick<SKRSContext2D, "font" | "measureText">;

function measureToken(ctx: MeasureCtx, token: string): { width: number; ascent: number; descent: number } {
  const m = ctx.measureText(token);
  const ascent = m.actualBoundingBoxAscent ?? m.emHeightAscent ?? 24;
  const descent = m.actualBoundingBoxDescent ?? m.emHeightDescent ?? 6;
  return { width: Math.ceil(m.width), ascent: Math.ceil(ascent), descent: Math.ceil(descent) };
}

function wrapTokensToLines(
  ctx: MeasureCtx,
  tokens: readonly CaptionToken[],
  maxLineWidthPx: number,
  maxLines: number,
  tokenGapPx: number,
): CaptionToken[][] {
  const lines: CaptionToken[][] = [];
  let current: CaptionToken[] = [];
  let currentWidth = 0;

  const lineWidth = (line: CaptionToken[]): number => {
    if (!line.length) return 0;
    let w = 0;
    for (let i = 0; i < line.length; i++) {
      w += measureToken(ctx, line[i]!.text).width;
      if (i < line.length - 1) w += tokenGapPx;
    }
    return w;
  };

  const flush = (): void => {
    if (current.length) {
      lines.push(current);
      current = [];
      currentWidth = 0;
    }
  };

  for (const token of tokens) {
    const tw = measureToken(ctx, token.text).width;
    const extra = current.length ? tokenGapPx + tw : tw;
    if (current.length && currentWidth + extra > maxLineWidthPx) {
      flush();
      if (lines.length >= maxLines) break;
    }
    current.push(token);
    currentWidth = lineWidth(current);
  }
  flush();

  if (lines.length > maxLines) {
    return lines.slice(0, maxLines);
  }
  return lines;
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
  const metrics = lineTokens.map((t) => ({ token: t, ...measureToken(ctx, t.text) }));
  const lineWidth =
    metrics.reduce((s, m) => s + m.width, 0) + Math.max(0, metrics.length - 1) * tokenGapPx;

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

  return { tokens: lineTokens, boxes, y: lineY, lineHeight };
}

/**
 * Compute token positions for up to two lines, RTL or LTR.
 */
export function layoutCaptionBlock(
  ctx: MeasureCtx,
  input: Pick<
    RenderPlateInput,
    | "text"
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
  >,
  fontFamily: string,
): CaptionLayoutResult {
  const tokens = tokenizeCaptionText(input.text);
  const direction = resolveTextDirection(input.text, input.direction);
  ctx.font = poCFontCss(fontFamily, input.fontSize, input.fontWeight);

  const lineTokenGroups = wrapTokensToLines(ctx, tokens, input.maxLineWidthPx, input.maxLines, input.tokenGapPx);

  const lineHeights = lineTokenGroups.map((group) => {
    let maxH = 0;
    for (const t of group) {
      const m = measureToken(ctx, t.text);
      maxH = Math.max(maxH, m.ascent + m.descent);
    }
    return maxH;
  });

  const blockHeight =
    lineHeights.reduce((a, b) => a + b, 0) + Math.max(0, lineTokenGroups.length - 1) * input.lineGapPx;

  const lineWidths = lineTokenGroups.map((group) => {
    let w = 0;
    for (let i = 0; i < group.length; i++) {
      w += measureToken(ctx, group[i]!.text).width;
      if (i < group.length - 1) w += input.tokenGapPx;
    }
    return w;
  });
  const blockWidth = Math.max(...lineWidths, 0);

  let blockTop: number;
  switch (input.position) {
    case "top":
      blockTop = Math.round(input.canvasHeight * 0.12);
      break;
    case "center":
      blockTop = Math.round((input.canvasHeight - blockHeight) / 2);
      break;
    case "bottom":
    default:
      blockTop = Math.round(input.canvasHeight * 0.72 - blockHeight);
      break;
  }

  const blockLeft = Math.round((input.canvasWidth - blockWidth) / 2);

  const lines: CaptionLineLayout[] = [];
  let yCursor = blockTop;

  for (let li = 0; li < lineTokenGroups.length; li++) {
    const group = lineTokenGroups[li]!;
    const lh = lineHeights[li] ?? input.fontSize;
    const lw = lineWidths[li] ?? 0;
    const originX = direction === "ltr" ? blockLeft : blockLeft + lw;
    lines.push(layoutLine(ctx, group, direction, yCursor, lh, originX, input.tokenGapPx));
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
  };
}
