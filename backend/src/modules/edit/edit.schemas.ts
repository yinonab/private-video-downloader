import { z } from "zod";
import { AppError, codes } from "../../types/errors";
import type { EditSpeedFactor, ResolvedEditPlan } from "./edit.types";

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

export const editOperationSchema = z.union([
  trimOpSchema,
  cropOpSchema,
  speedOpSchema,
  muteOpSchema,
  compressOpSchema,
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

export function resolveEditOperations(ops: EditOperation[]): ResolvedEditPlan {
  let trim: ResolvedEditPlan["trim"];
  let aspectRatio: ResolvedEditPlan["aspectRatio"] = "original";
  let speedFactor: EditSpeedFactor | undefined;
  let mute = false;
  let compressPreset: ResolvedEditPlan["compressPreset"] = "social";
  for (const op of ops) {
    switch (op.type) {
      case "trim":
        trim = { startSec: op.startSec, endSec: op.endSec };
        break;
      case "crop":
        aspectRatio = op.aspectRatio;
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
      default:
        break;
    }
  }
  return { trim, aspectRatio, speedFactor, mute, compressPreset };
}
