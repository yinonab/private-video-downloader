import { createCanvas, type SKRSContext2D } from "@napi-rs/canvas";
import type { BoxShape, RenderPlateInput, RenderPlateResult } from "./types";
import { layoutCaptionBlock } from "./layout";
import { ensureCaptionFont, captionFontCss } from "./fonts";
import { tokenizeCaptionText } from "./tokenize";

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

export async function renderCaptionHighlightPlate(input: RenderPlateInput): Promise<RenderPlateResult> {
  const fontLabel = await ensureCaptionFont(input.fontFamily);
  const canvas = createCanvas(input.canvasWidth, input.canvasHeight);
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, input.canvasWidth, input.canvasHeight);

  const layout = layoutCaptionBlock(ctx, { ...input, offsetY: input.offsetY }, fontLabel);
  const tokens = tokenizeCaptionText(input.text);
  const activeIdx = Math.max(0, Math.min(input.activeWordIndex, Math.max(0, tokens.length - 1)));

  ctx.font = captionFontCss(fontLabel, input.fontSize, input.fontWeight);
  ctx.textBaseline = "alphabetic";

  let activeDrawn = 0;

  if (input.drawBox) {
    for (const line of layout.lines) {
      for (const box of line.boxes) {
        if (box.tokenIndex !== activeIdx) continue;
        drawHighlightBox(
          ctx,
          box.x,
          box.y,
          box.width,
          box.height,
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
      ctx.fillStyle = isActive ? input.activeTextColor : input.normalTextColor;
      ctx.direction = "ltr";
      const m = ctx.measureText(token.text);
      const ascent = m.actualBoundingBoxAscent ?? m.emHeightAscent ?? input.fontSize;
      ctx.fillText(token.text, box.x, box.y + ascent);
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
