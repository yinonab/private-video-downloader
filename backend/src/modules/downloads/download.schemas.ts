import { z } from "zod";

const trimMin1 = z.preprocess((val) => (typeof val === "string" ? val.trim() : val), z.string().min(1));

export const createDownloadSchema = z.object({
  url: trimMin1,
  format: trimMin1,
  quality: z.preprocess((val) => {
    if (val == null || val === "") return undefined;
    const s = typeof val === "string" ? val.trim() : val;
    if (typeof s === "string" && s === "") return undefined;
    return s;
  }, z.string().min(1).optional()),
});

export type CreateDownloadBody = z.infer<typeof createDownloadSchema>;

export const listDownloadsQuerySchema = z.object({
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(30),
  status: z.string().optional(),
  platform: z.string().optional(),
});
