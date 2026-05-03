import dotenv from "dotenv";
import { z } from "zod";
import path from "node:path";

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().min(1),
  STORAGE_DIR: z.string().min(1),
  COOKIES_FILE: z.string().optional(),
  ADMIN_TOKEN: z.string().min(8),
  DEVICE_TOKEN_SECRET: z.string().min(16),
  DOWNLOAD_CONCURRENCY: z.coerce.number().min(1).default(3),
  DEFAULT_DAILY_LIMIT: z.coerce.number().min(1).default(20),
  ANALYZE_DAILY_LIMIT: z.coerce.number().min(1).default(200),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

const raw = parsed.data;

export const config = {
  ...raw,
  storageDir: path.resolve(raw.STORAGE_DIR),
  cookiesFile: raw.COOKIES_FILE ? path.resolve(raw.COOKIES_FILE) : undefined,
  isDev: raw.NODE_ENV === "development",
};

export type AppConfig = typeof config;
