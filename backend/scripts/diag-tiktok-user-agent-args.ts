/**
 * Local assert: TikTok-only yt-dlp User-Agent args (no network).
 * Run: npm run diag:tiktok-user-agent-args
 */
import assert from "node:assert/strict";
import dotenv from "dotenv";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function ensureDiagEnv(): void {
  const stubs: Record<string, string> = {
    DATABASE_URL: "postgresql://diag/diag",
    REDIS_URL: "redis://127.0.0.1:6379",
    STORAGE_DIR: path.join(backendRoot, "storage"),
    ADMIN_TOKEN: "diag-admin-token",
    DEVICE_TOKEN_SECRET: "diag-device-token-secret",
  };
  for (const [k, v] of Object.entries(stubs)) {
    if (!process.env[k]?.trim()) process.env[k] = v;
  }
}

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const {
    YTDLP_TIKTOK_USER_AGENT_DEFAULT,
    buildDownloadArgs,
    resolveYtDlpTikTokUserAgent,
    withYtDlpTikTokUserAgentArgs,
  } = await import("../src/services/ytdlp");

  const ua = resolveYtDlpTikTokUserAgent();
  assert.ok(ua.length > 20, "UA should be non-trivial");
  assert.equal(
    ua,
    process.env.YTDLP_TIKTOK_USER_AGENT?.trim() || YTDLP_TIKTOK_USER_AGENT_DEFAULT
  );

  const tiktokShort = withYtDlpTikTokUserAgentArgs(
    ["--no-config", "https://vt.tiktok.com/x/"],
    "https://vt.tiktok.com/ZS4v17Kj2/"
  );
  assert.equal(tiktokShort[0], "--user-agent");
  assert.equal(tiktokShort[1], ua);

  const tiktokWww = withYtDlpTikTokUserAgentArgs(["a"], "www.tiktok.com");
  assert.equal(tiktokWww[0], "--user-agent");

  const youtube = withYtDlpTikTokUserAgentArgs(
    ["--no-config"],
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  );
  assert.ok(!youtube.includes("--user-agent"), "YouTube must not get TikTok UA");

  const ig = withYtDlpTikTokUserAgentArgs(["x"], "https://www.instagram.com/reel/abc/");
  assert.ok(!ig.includes("--user-agent"), "Instagram must not get TikTok UA");

  const already = withYtDlpTikTokUserAgentArgs(
    ["--user-agent", "custom", "rest"],
    "https://www.tiktok.com/@x/video/1"
  );
  assert.equal(already[0], "--user-agent");
  assert.equal(already[1], "custom");

  const built = buildDownloadArgs({
    url: "https://vt.tiktok.com/ZS4v17Kj2/",
    deviceId: "diag-device",
    jobId: "diag-job",
    format: "best",
  });
  assert.equal(built.args[0], "--user-agent");
  assert.ok(built.args.includes("https://vt.tiktok.com/ZS4v17Kj2/"));

  const ytBuilt = buildDownloadArgs({
    url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    deviceId: "diag-device",
    jobId: "diag-job",
    format: "best",
  });
  assert.ok(!ytBuilt.args.includes("--user-agent"));

  console.log(
    JSON.stringify({
      ok: true,
      uaKind: ua.includes("Chrome/") ? "chrome_desktop" : "other",
    })
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
