import { createCanvas, type SKRSContext2D } from "@napi-rs/canvas";
import type { BoxShape, CaptionToken, RenderPlateInput, RenderPlateResult } from "./types";
import { layoutCaptionBlock } from "./layout";
import { ensureCaptionFont, captionFontCss } from "./fonts";
import { captionTokenDisplayText, tokenizeCaptionText } from "./tokenize";

/**
 * Active highlight plate top/height from the shared alphabetic baseline.
 * Uses font bounding metrics with an ink floor so the plate optically hugs the
 * active word without changing text draw Y / baselineY.
 */
export function highlightPlateBoxFromBaseline(
  baselineY: number,
  metrics: {
    readonly fontBoundingBoxAscent?: number;
    readonly fontBoundingBoxDescent?: number;
    readonly emHeightAscent?: number;
    readonly emHeightDescent?: number;
    readonly actualBoundingBoxAscent?: number;
    readonly actualBoundingBoxDescent?: number;
  },
  fallbackAscent: number,
  fallbackDescent: number,
): { readonly y: number; readonly height: number; readonly ascent: number; readonly descent: number } {
  const fontAscent = Math.ceil(
    metrics.fontBoundingBoxAscent ?? metrics.emHeightAscent ?? fallbackAscent,
  );
  const fontDescent = Math.ceil(
    metrics.fontBoundingBoxDescent ?? metrics.emHeightDescent ?? fallbackDescent,
  );
  const inkAscent = Math.ceil(metrics.actualBoundingBoxAscent ?? fontAscent);
  const inkDescent = Math.ceil(metrics.actualBoundingBoxDescent ?? fontDescent);
  const ascent = Math.max(1, fontAscent, inkAscent);
  const descent = Math.max(0, fontDescent, inkDescent);
  return {
    y: baselineY - ascent,
    height: ascent + descent,
    ascent,
    descent,
  };
}

function drawHighlightBox(
  ctx: SKRSContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  shape: BoxShape,
  padX: number,
  padY: number,
  fill: string,
): void {
  const bx = x - padX;
  const by = y - padY;
  const bw = w + padX * 2;
  const bh = h + padY * 2;
  const r = shape === "pill" ? bh / 2 : shape === "rounded" ? Math.min(12, bh / 3) : 2;

  const rgba = /^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$/.exec(fill);
  if (rgba) {
    ctx.globalAlpha = Number(rgba[4]);
    ctx.fillStyle = `rgb(${rgba[1]},${rgba[2]},${rgba[3]})`;
  } else {
    ctx.globalAlpha = 1;
    ctx.fillStyle = fill;
  }
  ctx.beginPath();
  if (shape === "rectangle") {
    ctx.rect(bx, by, bw, bh);
  } else {
    ctx.roundRect(bx, by, bw, bh, r);
  }
  ctx.fill();
  ctx.globalAlpha = 1;
}

function drawTokenText(
  ctx: SKRSContext2D,
  token: CaptionToken,
  box: { x: number; y: number; width: number; height: number },
  baselineY: number,
  direction: "rtl" | "ltr",
  fillStyle: string,
  outline?: { enabled: boolean; color: string; widthPx: number },
): void {
  const display = captionTokenDisplayText(token);
  ctx.direction = direction;
  ctx.textAlign = "left";
  ctx.textBaseline = "alphabetic";
  const x = box.x;
  // Shared line baseline — not per-token actualBoundingBoxAscent.
  const y = baselineY;

  if (outline?.enabled && outline.widthPx > 0) {
    ctx.strokeStyle = outline.color;
    ctx.lineWidth = outline.widthPx;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.miterLimit = 2;
    ctx.strokeText(display, x, y);
  }

  ctx.fillStyle = fillStyle;
  ctx.fillText(display, x, y);
}

export async function renderCaptionHighlightPlate(input: RenderPlateInput): Promise<RenderPlateResult> {
  const fontLabel = await ensureCaptionFont(input.fontFamily);
  const canvas = createCanvas(input.canvasWidth, input.canvasHeight);
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, input.canvasWidth, input.canvasHeight);

  const layout = layoutCaptionBlock(
    ctx,
    {
      ...input,
      offsetY: input.offsetY,
      canvas: { width: input.canvasWidth, height: input.canvasHeight },
    },
    fontLabel,
  );
  const tokens = tokenizeCaptionText(input.text);
  const activeIdx = Math.max(0, Math.min(input.activeWordIndex, Math.max(0, tokens.length - 1)));

  ctx.font = captionFontCss(fontLabel, input.fontSize, input.fontWeight);
  ctx.textBaseline = "alphabetic";

  const outline =
    input.outlineEnabled && input.outlineColorCss
      ? {
          enabled: true,
          color: input.outlineColorCss,
          widthPx: input.outlineWidthPx ?? 0,
        }
      : undefined;

  let activeDrawn = 0;

  if (input.drawBox) {
    for (const line of layout.lines) {
      for (const box of line.boxes) {
        if (box.tokenIndex !== activeIdx) continue;
        const token = tokens[box.tokenIndex];
        if (!token) continue;
        const measured = ctx.measureText(captionTokenDisplayText(token));
        const lineDescent = Math.max(0, line.lineHeight - line.ascent);
        const plate = highlightPlateBoxFromBaseline(
          line.baselineY,
          measured,
          line.ascent,
          lineDescent,
        );
        drawHighlightBox(
          ctx,
          box.x,
          plate.y,
          box.width,
          plate.height,
          input.boxShape,
          input.boxPaddingXPx,
          input.boxPaddingYPx,
          input.boxColor,
        );
      }
    }
  }

  for (const line of layout.lines) {
    for (const box of line.boxes) {
      const token = tokens[box.tokenIndex];
      if (!token) continue;
      const isActive = box.tokenIndex === activeIdx;
      drawTokenText(
        ctx,
        token,
        box,
        line.baselineY,
        layout.direction,
        isActive ? input.activeTextColor : input.normalTextColor,
        outline,
      );
      if (isActive) activeDrawn += 1;
    }
  }

  return {
    png: await canvas.encode("png"),
    layout,
    activeTokenIndex: activeIdx,
    activeTokenCount: activeDrawn,
  };
}
