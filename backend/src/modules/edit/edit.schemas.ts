import { z } from "zod";
import { AppError, codes } from "../../types/errors";
import { normalizeCaptionSegmentsForBurn } from "./captionSegments.util";
import type {
  CaptionsBurnInV1Resolved,
  CaptionsStyleApi,
  CaptionsStyleResolved,
  EditFormatMode,
  EditRotationDegrees,
  EditSpeedFactor,
  ResolvedEditPlan,
} from "./edit.types";

const INVALID_CAPTION_SEGMENTS_EN = "The edited captions are invalid.";

const UNSUPPORTED_FORMAT_EN = "This format mode is not supported.";
const UNSUPPORTED_ROTATION_EN = "This rotation option is not supported.";
const UNSUPPORTED_CAPTIONS_MODE_EN = "This captions mode is not supported.";
const UNSUPPORTED_CAPTIONS_LANGUAGE_EN = "This captions language setting is not supported.";
const UNSUPPORTED_CAPTIONS_STYLE_EN = "This captions style is not supported.";
const UNSUPPORTED_CAPTIONS_POSITION_EN = "This captions position is not supported.";
const UNSUPPORTED_CAPTIONS_OFFSET_EN = "This captions position is not supported.";
const UNSUPPORTED_CAPTIONS_FONT_SIZE_EN = "This captions size is not supported.";
const UNSUPPORTED_CAPTIONS_FONT_FAMILY_EN = "This caption font is not supported.";
const UNSUPPORTED_CAPTIONS_COLOR_EN = "This captions color is not supported.";
const CANON_EDIT_SPEED_FACTORS = [0.5, 1.25, 1.5, 2] as const satisfies readonly EditSpeedFactor[];

function normalizeEditSpeedFactor(n: unknown): EditSpeedFactor | undefined {
  if (typeof n !== "number" || !Number.isFinite(n)) return undefined;
  for (const f of CANON_EDIT_SPEED_FACTORS) {
    if (Math.abs(f - n) < 1e-6) return f;
  }
  return undefined;
}

const UNSUPPORTED_SPEED_EN = "This speed option is not supported.";

const trimOpSchema = z
  .object({
    type: z.literal("trim"),
    startSec: z.number().finite().min(0),
    endSec: z.number().finite().min(0),
  })
  .strict()
  .refine((d) => d.endSec > d.startSec, {
    message: "trim.endSec must be greater than trim.startSec",
  });

const cropOpSchema = z
  .object({
    type: z.literal("crop"),
    aspectRatio: z.enum(["original", "9:16", "1:1", "16:9", "4:5"]),
    mode: z.literal("centerCrop").optional(),
  })
  .strict();

const formatOpSchema = z
  .object({
    type: z.literal("format"),
    aspectRatio: z.enum(["9:16", "1:1", "16:9", "4:5"]),
    mode: z.enum(["fill", "fit_blur"]).optional(),
  })
  .strict();

const muteOpSchema = z.object({ type: z.literal("mute") }).strict();

const speedFactorSchema = z.union([
  z.literal(0.5),
  z.literal(1.25),
  z.literal(1.5),
  z.literal(2),
]);

const speedOpSchema = z
  .object({
    type: z.literal("speed"),
    factor: speedFactorSchema,
  })
  .strict();

const compressOpSchema = z
  .object({
    type: z.literal("compress"),
    preset: z.enum(["original", "social", "small"]),
  })
  .strict();

const rotateOpSchema = z
  .object({
    type: z.literal("rotate"),
    degrees: z.union([z.literal(90), z.literal(180), z.literal(270)]),
  })
  .strict();

const CAPTION_SEGMENT_MIN_DURATION_SEC = 0.3;

const CAPTIONS_STYLE_API = [
  "default",
  "clean",
  "bold",
  "dark_box",
  "clean_pro",
  "bold_social",
  "yellow_headline",
  "dark_bubble",
  "highlight_box",
] as const;

const CAPTIONS_FONT_SIZE = [
  "extra_small",
  "small",
  "medium",
  "large",
  "x_large",
  "xx_large",
] as const;

const CAPTIONS_COLOR = ["white", "yellow", "purple", "mint"] as const;

const CAPTIONS_FONT_FAMILY = [
  "default",
  "heebo",
  "rubik",
  "assistant",
  "noto_sans_hebrew",
] as const;

const captionSegmentWireSchema = z
  .object({
    startSec: z.number().finite().min(0),
    endSec: z.number().finite(),
    text: z.string(),
  })
  .strict()
  .refine((d) => d.endSec > d.startSec, {
    message: "segments[].endSec must be greater than startSec",
  })
  .refine((d) => d.endSec >= d.startSec + CAPTION_SEGMENT_MIN_DURATION_SEC, {
    message: "segments[].duration must be at least 0.3 seconds",
  });

const captionsAutoOpSchema = z
  .object({
    type: z.literal("captions"),
    mode: z.literal("auto"),
    language: z.literal("auto"),
    burnIn: z.literal(true),
    style: z.enum(CAPTIONS_STYLE_API),
    fontSize: z.enum(CAPTIONS_FONT_SIZE).optional(),
    fontFamily: z.enum(CAPTIONS_FONT_FAMILY).optional(),
    position: z.enum(["top", "bottom"]).optional(),
    color: z.enum(CAPTIONS_COLOR).optional(),
    offsetX: z.number().int().min(-240).max(240).optional(),
    offsetY: z.number().int().min(-180).max(180).optional(),
  })
  .strict();

const captionsSegmentsOpSchema = z
  .object({
    type: z.literal("captions"),
    mode: z.literal("segments"),
    language: z.literal("auto"),
    burnIn: z.literal(true),
    style: z.enum(CAPTIONS_STYLE_API),
    fontSize: z.enum(CAPTIONS_FONT_SIZE).optional(),
    fontFamily: z.enum(CAPTIONS_FONT_FAMILY).optional(),
    position: z.enum(["top", "bottom"]).optional(),
    color: z.enum(CAPTIONS_COLOR).optional(),
    offsetX: z.number().int().min(-240).max(240).optional(),
    offsetY: z.number().int().min(-180).max(180).optional(),
    segments: z.array(captionSegmentWireSchema).min(1),
  })
  .strict();

export const captionsOpSchema = z.discriminatedUnion("mode", [captionsAutoOpSchema, captionsSegmentsOpSchema]);

export const captionsDraftTrimSpeedOpSchema = z.union([trimOpSchema, speedOpSchema]);

export const captionsDraftRequestSchema = z
  .object({
    sourceDownloadJobId: z.string().uuid().optional(),
    sourceUploadId: z.string().uuid().optional(),
    operations: z.array(captionsDraftTrimSpeedOpSchema).default([]),
  })
  .strict();

export type CaptionsDraftRequestBody = z.infer<typeof captionsDraftRequestSchema>;

export const editOperationSchema = z.union([
  trimOpSchema,
  cropOpSchema,
  formatOpSchema,
  rotateOpSchema,
  speedOpSchema,
  muteOpSchema,
  compressOpSchema,
  captionsOpSchema,
]);

export const createEditJobSchema = z
  .object({
    sourceDownloadJobId: z.string().uuid().optional(),
    sourceUploadId: z.string().uuid().optional(),
    operations: z.array(editOperationSchema).min(1),
  })
  .strict();

export type CreateEditJobBody = z.infer<typeof createEditJobSchema>;

export type EditOperation = z.infer<typeof editOperationSchema>;

export function unsupportedSpeedFactorErrorFromUnknownBody(body: unknown): AppError | null {
  if (body == null || typeof body !== "object") return null;
  const ops = (body as { operations?: unknown }).operations;
  if (!Array.isArray(ops)) return null;
  for (const raw of ops) {
    if (raw == null || typeof raw !== "object") continue;
    const o = raw as { type?: unknown; factor?: unknown };
    if (o.type !== "speed") continue;
    if (typeof o.factor !== "number" || !Number.isFinite(o.factor)) continue;
    if (normalizeEditSpeedFactor(o.factor) !== undefined) continue;
    return new AppError(codes.UNSUPPORTED_SPEED_FACTOR, UNSUPPORTED_SPEED_EN, 400);
  }
  return null;
}

export function unsupportedFormatModeErrorFromUnknownBody(body: unknown): AppError | null {
  if (body == null || typeof body !== "object") return null;
  const ops = (body as { operations?: unknown }).operations;
  if (!Array.isArray(ops)) return null;
  const ALLOWED = new Set(["fill", "fit_blur"]);
  for (const raw of ops) {
    if (raw == null || typeof raw !== "object") continue;
    const o = raw as { type?: unknown; mode?: unknown };
    if (o.type !== "format") continue;
    if (o.mode === undefined || o.mode === null) continue;
    if (typeof o.mode !== "string" || !ALLOWED.has(o.mode)) {
      return new AppError(codes.UNSUPPORTED_FORMAT_MODE, UNSUPPORTED_FORMAT_EN, 400);
    }
  }
  return null;
}

export function unsupportedRotationErrorFromUnknownBody(body: unknown): AppError | null {
  if (body == null || typeof body !== "object") return null;
  const ops = (body as { operations?: unknown }).operations;
  if (!Array.isArray(ops)) return null;
  for (const raw of ops) {
    if (raw == null || typeof raw !== "object") continue;
    const o = raw as { type?: unknown; degrees?: unknown };
    if (o.type !== "rotate") continue;
    const d = o.degrees;
    if (d === 90 || d === 180 || d === 270) continue;
    if (typeof d === "number" && Number.isFinite(d)) {
      return new AppError(codes.UNSUPPORTED_ROTATION, UNSUPPORTED_ROTATION_EN, 400);
    }
    return new AppError(codes.UNSUPPORTED_ROTATION, UNSUPPORTED_ROTATION_EN, 400);
  }
  return null;
}

export function captionsFieldErrorsFromUnknownBody(body: unknown): AppError | null {
  if (body == null || typeof body !== "object") return null;
  const ops = (body as { operations?: unknown }).operations;
  if (!Array.isArray(ops)) return null;
  for (const raw of ops) {
    if (raw == null || typeof raw !== "object") continue;
    const o = raw as Record<string, unknown>;
    if (o.type !== "captions") continue;
    if (Object.prototype.hasOwnProperty.call(o, "mode")) {
      const md = o.mode;
      if (md !== "auto" && md !== "segments") {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_MODE, UNSUPPORTED_CAPTIONS_MODE_EN, 400);
      }
      if (md === "segments") {
        const segs = o.segments;
        if (!Array.isArray(segs) || segs.length < 1) {
          return new AppError(codes.INVALID_CAPTION_SEGMENTS, INVALID_CAPTION_SEGMENTS_EN, 400);
        }
        for (const rawSeg of segs) {
          if (rawSeg == null || typeof rawSeg !== "object") {
            return new AppError(codes.INVALID_CAPTION_SEGMENTS, INVALID_CAPTION_SEGMENTS_EN, 400);
          }
          const s = rawSeg as Record<string, unknown>;
          const a = s.startSec;
          const b = s.endSec;
          const txt = s.text;
          if (typeof txt !== "string") {
            return new AppError(codes.INVALID_CAPTION_SEGMENTS, INVALID_CAPTION_SEGMENTS_EN, 400);
          }
          if (typeof a !== "number" || !Number.isFinite(a) || a < 0) {
            return new AppError(codes.INVALID_CAPTION_SEGMENTS, INVALID_CAPTION_SEGMENTS_EN, 400);
          }
          if (typeof b !== "number" || !Number.isFinite(b) || b <= a) {
            return new AppError(codes.INVALID_CAPTION_SEGMENTS, INVALID_CAPTION_SEGMENTS_EN, 400);
          }
          if (b < a + CAPTION_SEGMENT_MIN_DURATION_SEC) {
            return new AppError(codes.INVALID_CAPTION_SEGMENTS, INVALID_CAPTION_SEGMENTS_EN, 400);
          }
        }
      }
    }
    if (Object.prototype.hasOwnProperty.call(o, "language")) {
      if (o.language !== "auto") {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_LANGUAGE, UNSUPPORTED_CAPTIONS_LANGUAGE_EN, 400);
      }
    }
    if (Object.prototype.hasOwnProperty.call(o, "style")) {
      const st = o.style;
      const allowedStyle = new Set<string>(CAPTIONS_STYLE_API);
      if (typeof st !== "string" || !allowedStyle.has(st)) {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_STYLE, UNSUPPORTED_CAPTIONS_STYLE_EN, 400);
      }
    }
    const allowedFs = new Set<string>(CAPTIONS_FONT_SIZE);
    if (Object.prototype.hasOwnProperty.call(o, "fontSize")) {
      const fs = o.fontSize;
      if (fs !== undefined && fs !== null && (typeof fs !== "string" || !allowedFs.has(fs))) {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_FONT_SIZE, UNSUPPORTED_CAPTIONS_FONT_SIZE_EN, 400);
      }
    }
    const allowedFf = new Set<string>(CAPTIONS_FONT_FAMILY);
    if (Object.prototype.hasOwnProperty.call(o, "fontFamily")) {
      const ff = o.fontFamily;
      if (ff !== undefined && ff !== null && (typeof ff !== "string" || !allowedFf.has(ff))) {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_FONT_FAMILY, UNSUPPORTED_CAPTIONS_FONT_FAMILY_EN, 400);
      }
    }
    const allowedPos = new Set(["top", "bottom"]);
    if (Object.prototype.hasOwnProperty.call(o, "position")) {
      const p = o.position;
      if (p !== undefined && p !== null && (typeof p !== "string" || !allowedPos.has(p))) {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_POSITION, UNSUPPORTED_CAPTIONS_POSITION_EN, 400);
      }
    }
    const allowedCol = new Set<string>(CAPTIONS_COLOR);
    if (Object.prototype.hasOwnProperty.call(o, "color")) {
      const c = o.color;
      if (c !== undefined && c !== null && (typeof c !== "string" || !allowedCol.has(c))) {
        return new AppError(codes.UNSUPPORTED_CAPTIONS_COLOR, UNSUPPORTED_CAPTIONS_COLOR_EN, 400);
      }
    }
    if (Object.prototype.hasOwnProperty.call(o, "burnIn")) {
      if (o.burnIn !== true) {
        return new AppError(
          codes.BAD_REQUEST,
          "Captions burnIn must be true in V1.",
          400
        );
      }
    }

    // Defense in depth alongside Zod (invalid integers / floats from non-typed clients).
    if (Object.prototype.hasOwnProperty.call(o, "offsetX")) {
      const x = o.offsetX;
      if (x !== undefined && x !== null) {
        if (typeof x !== "number" || !Number.isFinite(x) || !Number.isInteger(x) || x < -240 || x > 240) {
          return new AppError(codes.UNSUPPORTED_CAPTIONS_POSITION_OFFSET, UNSUPPORTED_CAPTIONS_OFFSET_EN, 400);
        }
      }
    }
    if (Object.prototype.hasOwnProperty.call(o, "offsetY")) {
      const y = o.offsetY;
      if (y !== undefined && y !== null) {
        if (typeof y !== "number" || !Number.isFinite(y) || !Number.isInteger(y) || y < -180 || y > 180) {
          return new AppError(codes.UNSUPPORTED_CAPTIONS_POSITION_OFFSET, UNSUPPORTED_CAPTIONS_OFFSET_EN, 400);
        }
      }
    }
  }
  return null;
}

function normalizeCaptionsStyle(style: CaptionsStyleApi): CaptionsStyleResolved {
  if (style === "default") return "clean";
  return style;
}

function normalizeCaptionsFontFamily(ff: (typeof CAPTIONS_FONT_FAMILY)[number] | undefined): CaptionsBurnInV1Resolved["fontFamily"] {
  return ff ?? "default";
}

const CAPTIONS_OFFSET_X_CLAMP = [-240, 240] as const;
const CAPTIONS_OFFSET_Y_CLAMP = [-180, 180] as const;

/** Defensive clamps after validation (parity with Flutter UI). */
export function clampCaptionsBurnInOffsets(
  ox: unknown,
  oy: unknown
): { offsetX: number; offsetY: number } {
  const xi = typeof ox === "number" && Number.isFinite(ox) ? Math.round(ox) : 0;
  const yi = typeof oy === "number" && Number.isFinite(oy) ? Math.round(oy) : 0;
  return {
    offsetX: Math.min(CAPTIONS_OFFSET_X_CLAMP[1], Math.max(CAPTIONS_OFFSET_X_CLAMP[0], xi)),
    offsetY: Math.min(CAPTIONS_OFFSET_Y_CLAMP[1], Math.max(CAPTIONS_OFFSET_Y_CLAMP[0], yi)),
  };
}

export function resolveEditOperations(ops: EditOperation[]): ResolvedEditPlan {
  let trim: ResolvedEditPlan["trim"];
  let aspectRatio: ResolvedEditPlan["aspectRatio"] = "original";
  let formatModeApplied: EditFormatMode | undefined;
  let rotationDegrees: EditRotationDegrees | undefined;
  let speedFactor: EditSpeedFactor | undefined;
  let mute = false;
  let compressPreset: ResolvedEditPlan["compressPreset"] = "social";
  let captionsBurnInV1: CaptionsBurnInV1Resolved | undefined;
  for (const op of ops) {
    switch (op.type) {
      case "trim":
        trim = { startSec: op.startSec, endSec: op.endSec };
        break;
      case "crop":
        aspectRatio = op.aspectRatio;
        formatModeApplied = "fill";
        break;
      case "format":
        aspectRatio = op.aspectRatio;
        formatModeApplied = op.mode ?? "fill";
        break;
      case "rotate":
        rotationDegrees = op.degrees;
        break;
      case "speed":
        speedFactor = op.factor;
        break;
      case "mute":
        mute = true;
        break;
      case "compress":
        compressPreset = op.preset;
        break;
      case "captions": {
        const styleResolved = normalizeCaptionsStyle(op.style);
        const { offsetX, offsetY } = clampCaptionsBurnInOffsets(op.offsetX, op.offsetY);
        const fontFamily = normalizeCaptionsFontFamily(op.fontFamily);
        const base = {
          language: "auto" as const,
          burnIn: true as const,
          style: styleResolved,
          fontSize: op.fontSize ?? "medium",
          fontFamily,
          position: op.position ?? "bottom",
          color: op.color ?? "white",
          offsetX,
          offsetY,
        };
        if (op.mode === "auto") {
          captionsBurnInV1 = {
            mode: "auto",
            ...base,
          };
        } else {
          const normalized = normalizeCaptionSegmentsForBurn(op.segments);
          captionsBurnInV1 = {
            mode: "segments",
            ...base,
            segments: normalized,
          };
        }
        break;
      }
      default:
        break;
    }
  }
  const formatMode =
    aspectRatio === "original" ? undefined : (formatModeApplied ?? "fill");
  const out: ResolvedEditPlan = {
    trim,
    aspectRatio,
    formatMode,
    speedFactor,
    mute,
    compressPreset,
  };
  if (rotationDegrees !== undefined) {
    out.rotationDegrees = rotationDegrees;
  }
  if (captionsBurnInV1 !== undefined) {
    out.captionsBurnInV1 = captionsBurnInV1;
  }
  return out;
}