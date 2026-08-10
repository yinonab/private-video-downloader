/**
 * Regression checks for yt-dlp stderr → analyze error classification.
 * Run: npm run diag:ytdlp-classify
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

type Case = {
  name: string;
  stderr: string;
  urlHost: string;
  expectClassification: string;
  expectCode: string;
};

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const { codes } = await import("../src/types/errors");
  const { classifyYtDlpStderr } = await import("../src/services/ytdlp");
  const { mapYtdlpAnalyzeFailure } = await import("../src/services/ytdlpAnalyzeErrors");

  const cases: Case[] = [
    {
      name: "YouTube bot/auth challenge",
      stderr:
        "ERROR: [youtube] abc: Sign in to confirm you're not a bot. Use --cookies-from-browser or --cookies...",
      urlHost: "www.youtube.com",
      expectClassification: "auth_required",
      expectCode: codes.YOUTUBE_AUTH_REQUIRED,
    },
    {
      name: "YouTube rotated cookies",
      stderr: "The provided YouTube account cookies are no longer valid.",
      urlHost: "www.youtube.com",
      expectClassification: "auth_required",
      expectCode: codes.YOUTUBE_AUTH_REQUIRED,
    },
    {
      name: "YouTube geo restriction",
      stderr:
        "The uploader has not made this video available in your country\nYou might want to use a VPN or a proxy server",
      urlHost: "www.youtube.com",
      expectClassification: "geo_restricted",
      expectCode: codes.YOUTUBE_GEO_RESTRICTED,
    },
    {
      name: "Facebook no formats",
      stderr: "ERROR: [facebook] https://www.facebook.com/watch/?v=123: No video formats found!",
      urlHost: "www.facebook.com",
      expectClassification: "no_formats_found",
      expectCode: codes.FACEBOOK_NO_FORMATS_FOUND,
    },
    {
      name: "Generic no formats",
      stderr: "No video formats found!",
      urlHost: "example.com",
      expectClassification: "no_formats_found",
      expectCode: codes.NO_DOWNLOADABLE_FORMATS,
    },
  ];

  let passed = 0;
  for (const c of cases) {
    const classification = classifyYtDlpStderr(c.stderr);
    assert.equal(classification, c.expectClassification, `${c.name}: classification`);

    const mapped = mapYtdlpAnalyzeFailure(classification, c.urlHost, c.stderr);
    assert.ok(mapped, `${c.name}: expected mapped analyze error`);
    assert.equal(mapped!.code, c.expectCode, `${c.name}: code`);
    assert.equal(mapped!.classification, c.expectClassification, `${c.name}: mapped classification`);
    passed++;
  }

  // TikTok rehydration: classified explicitly; no specialized client mapping (ANALYZE_FAILED path).
  {
    const stderr =
      "ERROR: [TikTok] abc: Unable to extract universal data for rehydration; please report this issue";
    const classification = classifyYtDlpStderr(stderr);
    assert.equal(classification, "tiktok_rehydration", "TikTok rehydration classification");
    const mapped = mapYtdlpAnalyzeFailure(classification, "www.tiktok.com", stderr);
    assert.equal(mapped, null, "TikTok rehydration keeps generic Analyze failure mapping");
    passed++;
  }

  // TikTok webpage unexpected: host-gated promotion only.
  {
    const stderr = "ERROR: [TikTok] Unexpected response from webpage request";
    assert.equal(
      classifyYtDlpStderr(stderr, { urlHost: "www.tiktok.com" }),
      "tiktok_webpage_unexpected",
      "TikTok Unexpected webpage classification"
    );
    assert.equal(
      classifyYtDlpStderr(stderr, { urlHost: "www.youtube.com" }),
      "unknown",
      "non-TikTok Unexpected stays unknown"
    );
    assert.equal(
      classifyYtDlpStderr(stderr),
      "unknown",
      "Unexpected without urlHost stays unknown"
    );
    const mapped = mapYtdlpAnalyzeFailure(
      "tiktok_webpage_unexpected",
      "www.tiktok.com",
      stderr
    );
    assert.equal(mapped, null, "TikTok webpage unexpected keeps generic Analyze mapping");
    passed++;
  }

  // Must not confuse unsupported URL with rehydration.
  {
    const classification = classifyYtDlpStderr("ERROR: Unsupported URL: https://example.com/x");
    assert.equal(classification, "unsupported_url");
    passed++;
  }

  console.log(`diag:ytdlp-classify OK (${passed}/${cases.length + 3} cases)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
