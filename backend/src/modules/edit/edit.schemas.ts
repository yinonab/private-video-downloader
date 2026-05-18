import { z } from "zod";
import type { ResolvedEditPlan } from "./edit.types";

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

const compressOpSchema = z
  .object({
    type: z.literal("compress"),
    preset: z.enum(["original", "social", "small"]),
  })
  .strict();

export const editOperationSchema = z.union([
  trimOpSchema,
  cropOpSchema,
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

export function resolveEditOperations(ops: EditOperation[]): ResolvedEditPlan {
  let trim: ResolvedEditPlan["trim"];
  let aspectRatio: ResolvedEditPlan["aspectRatio"] = "original";
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
  return { trim, aspectRatio, mute, compressPreset };
}
