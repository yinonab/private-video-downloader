import { z } from "zod";

export const createDownloadSchema = z.object({
  url: z.string().min(1),
  format: z.string().min(1),
  quality: z.string().optional(),
});

export type CreateDownloadBody = z.infer<typeof createDownloadSchema>;

export const listDownloadsQuerySchema = z.object({
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(30),
  status: z.string().optional(),
  platform: z.string().optional(),
});
