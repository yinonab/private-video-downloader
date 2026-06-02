import { readFileSync, statSync } from "node:fs";
import { createCanvas, loadImage } from "@napi-rs/canvas";

export type PlateInspection = {
  readonly width: number;
  readonly height: number;
  readonly fileSizeBytes: number;
  readonly nonTransparentPixelCount: number;
  readonly boundingBox: {
    readonly minX: number;
    readonly minY: number;
    readonly maxX: number;
    readonly maxY: number;
  } | null;
  readonly maxAlpha: number;
  readonly isEffectivelyEmpty: boolean;
};

const MIN_VISIBLE_PIXELS = 48;
const MIN_MAX_ALPHA = 8;

/**
 * Safe plate metadata for overlay QA (no caption text).
 */
export async function inspectCaptionPlate(pngPath: string): Promise<PlateInspection> {
  const fileSizeBytes = statSync(pngPath).size;
  const img = await loadImage(readFileSync(pngPath));
  const width = img.width;
  const height = img.height;
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext("2d");
  ctx.drawImage(img, 0, 0);
  const { data } = ctx.getImageData(0, 0, width, height);

  let nonTransparentPixelCount = 0;
  let maxAlpha = 0;
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const a = data[(y * width + x) * 4 + 3]!;
      if (a <= 0) continue;
      nonTransparentPixelCount += 1;
      if (a > maxAlpha) maxAlpha = a;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  const boundingBox =
    maxX >= 0
      ? { minX, minY, maxX, maxY }
      : null;

  const isEffectivelyEmpty =
    nonTransparentPixelCount < MIN_VISIBLE_PIXELS || maxAlpha < MIN_MAX_ALPHA;

  return {
    width,
    height,
    fileSizeBytes,
    nonTransparentPixelCount,
    boundingBox,
    maxAlpha,
    isEffectivelyEmpty,
  };
}

export async function assertHighlightPlatesVisible(platePaths: readonly string[]): Promise<void> {
  const unique = [...new Set(platePaths)];
  for (const p of unique) {
    const meta = await inspectCaptionPlate(p);
    if (meta.isEffectivelyEmpty) {
      throw new Error(
        `caption_highlight_empty_plate:w=${meta.width}:h=${meta.height}:px=${meta.nonTransparentPixelCount}:a=${meta.maxAlpha}`,
      );
    }
  }
}
