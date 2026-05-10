import { z } from "zod";

export const analyzeBodySchema = z.object({
  /** Accept plain host/path paste; [normalizeUrl] enforces a valid http(s) URL. */
  url: z.string().trim().min(1, "url required"),
});
