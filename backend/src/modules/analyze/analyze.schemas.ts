import { z } from "zod";

export const analyzeBodySchema = z.object({
  url: z.string().url(),
});
