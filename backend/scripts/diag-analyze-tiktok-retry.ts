/**
 * Focused Analyze TikTok transient extraction retry coverage (Rank 4).
 * Run: npm run diag:analyze-tiktok-retry
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

const REHYDRATION_STDERR =
  "ERROR: [TikTok] 123: Unable to extract universal data for rehydration; please report this issue on https://github.com/yt-dlp/yt-dlp/issues?q= , filling out the appropriate issue template. Confirm you are on the latest version using  yt-dlp -U";

const UNEXPECTED_STDERR = "ERROR: [TikTok] Unexpected response from webpage request";

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const { classifyYtDlpStderr, YtdlpMetadataError } = await import("../src/services/ytdlp");
  const {
    isTikTokTransientExtractionFailure,
    isTikTokTransientExtractionRetryEligible,
    TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS,
  } = await import("../src/services/ytdlpAnalyzeErrors");
  const { fetchMetadataJsonForAnalyze } = await import(
    "../src/services/analyzeTikTokRehydrationRetry"
  );
  const { hostnameIsTikTok } = await import("../src/services/urlSafety");

  assert.equal(hostnameIsTikTok("www.tiktok.com"), true);
  assert.equal(hostnameIsTikTok("vt.tiktok.com"), true);
  assert.equal(hostnameIsTikTok("vm.tiktok.com"), true);
  assert.equal(hostnameIsTikTok("www.youtube.com"), false);
  assert.equal(TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS, 3);

  assert.equal(classifyYtDlpStderr(REHYDRATION_STDERR), "tiktok_rehydration");
  assert.equal(
    classifyYtDlpStderr(UNEXPECTED_STDERR, { urlHost: "www.tiktok.com" }),
    "tiktok_webpage_unexpected"
  );
  assert.equal(
    classifyYtDlpStderr(UNEXPECTED_STDERR, { urlHost: "www.youtube.com" }),
    "unknown",
    "non-TikTok Unexpected must not promote"
  );

  assert.equal(isTikTokTransientExtractionFailure("tiktok_rehydration"), true);
  assert.equal(isTikTokTransientExtractionFailure("tiktok_webpage_unexpected"), true);
  assert.equal(isTikTokTransientExtractionFailure("unsupported_url"), false);
  assert.equal(isTikTokTransientExtractionFailure("auth_required"), false);
  assert.equal(isTikTokTransientExtractionFailure("unknown"), false);

  // Eligibility: attempts 1 and 2 eligible for transient; attempt 3 not
  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    true
  );
  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_webpage_unexpected",
      attempt: 2,
    }),
    true
  );
  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 3,
    }),
    false,
    "attempt 3 never eligible for another retry"
  );
  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "unsupported_url",
      attempt: 1,
    }),
    false
  );
  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.youtube.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    false
  );

  const okMeta = {
    id: "diag",
    title: "ok",
    extractor: "TikTok",
    formats: [{ format_id: "1", ext: "mp4", height: 720 }],
  };

  // 6) attempt 1 rehydration → attempt 2 success => 2 total
  {
    let calls = 0;
    const t0 = Date.now();
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/1",
      "www.tiktok.com",
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        return okMeta;
      }
    );
    const elapsed = Date.now() - t0;
    assert.equal(out.ok, true);
    if (out.ok) {
      assert.equal(out.attempts, 2);
      assert.equal(out.retryEligible, true);
      assert.equal(out.retryResult, "success");
    }
    assert.equal(calls, 2);
    assert.ok(elapsed < 500, `immediate retry expected; elapsed=${elapsed}ms`);
    console.log(`case6 rehydration→success OK (elapsedMs=${elapsed})`);
  }

  // 7) attempt 1 unexpected → attempt 2 success => 2 total
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/7",
      "www.tiktok.com",
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_webpage_unexpected", UNEXPECTED_STDERR);
        }
        return okMeta;
      }
    );
    assert.equal(out.ok, true);
    if (out.ok) assert.equal(out.attempts, 2);
    assert.equal(calls, 2);
    console.log("case7 unexpected→success OK");
  }

  // 8) rehydration → unexpected → success => exactly 3
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/8",
      "www.tiktok.com",
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        if (calls === 2) {
          throw new YtdlpMetadataError("tiktok_webpage_unexpected", UNEXPECTED_STDERR);
        }
        return okMeta;
      }
    );
    assert.equal(out.ok, true);
    if (out.ok) assert.equal(out.attempts, 3);
    assert.equal(calls, 3);
    console.log("case8 rehydration→unexpected→success OK");
  }

  // 9) unexpected → rehydration → success => exactly 3
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/9",
      "www.tiktok.com",
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_webpage_unexpected", UNEXPECTED_STDERR);
        }
        if (calls === 2) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        return okMeta;
      }
    );
    assert.equal(out.ok, true);
    if (out.ok) assert.equal(out.attempts, 3);
    assert.equal(calls, 3);
    console.log("case9 unexpected→rehydration→success OK");
  }

  // 10) transient → transient → transient => exactly 3, then fail
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/10",
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError(
          calls % 2 === 1 ? "tiktok_rehydration" : "tiktok_webpage_unexpected",
          "transient"
        );
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 3);
      assert.equal(out.retryEligible, true);
      assert.equal(out.retryResult, "failure");
      assert.equal(out.error.classification, "tiktok_rehydration");
    }
    assert.equal(calls, 3);
    console.log("case10 triple transient fail OK");
  }

  // 11) transient → hard failure => stop at 2, no third
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/11",
      "www.tiktok.com",
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        throw new YtdlpMetadataError("unsupported_url", "ERROR: Unsupported URL");
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 2);
      assert.equal(out.error.classification, "unsupported_url");
      assert.equal(out.retryResult, "failure");
    }
    assert.equal(calls, 2);
    console.log("case11 transient→hard stop at 2 OK");
  }

  // 12) first success => exactly 1
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/12",
      "www.tiktok.com",
      async () => {
        calls += 1;
        return okMeta;
      }
    );
    assert.equal(out.ok, true);
    if (out.ok) {
      assert.equal(out.attempts, 1);
      assert.equal(out.retryResult, "not_attempted");
    }
    assert.equal(calls, 1);
    console.log("case12 first-success single call OK");
  }

  // Unsupported / photo / auth / unknown / youtube — no retry
  for (const [label, classification] of [
    ["unsupported", "unsupported_url"],
    ["auth", "auth_required"],
    ["unknown", "unknown"],
  ] as const) {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      `https://www.tiktok.com/@x/video/${label}`,
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError(classification, label);
      }
    );
    assert.equal(out.ok, false);
    assert.equal(calls, 1, `${label} no retry`);
    console.log(`case-hard ${label} no-retry OK`);
  }

  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.youtube.com/watch?v=abc",
      "www.youtube.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
      }
    );
    assert.equal(calls, 1);
    assert.equal(out.ok, false);
    console.log("case-youtube no-retry OK");
  }

  // Combined timing still includes retries
  {
    const { startPerfTimer } = await import("../src/services/analyzePerf");
    const total = startPerfTimer();
    let calls = 0;
    await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/timing",
      "www.tiktok.com",
      async () => {
        calls += 1;
        await new Promise((r) => setTimeout(r, 15));
        if (calls < 3) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        return okMeta;
      }
    );
    const totalMs = total.elapsedMs();
    assert.ok(totalMs >= 40, `analyze_total-style timer includes retries; got ${totalMs}`);
    assert.equal(calls, 3);
    console.log(`case-timing combined OK (totalMs=${Math.round(totalMs)})`);
  }

  console.log("diag:analyze-tiktok-retry OK (Rank 4)");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
