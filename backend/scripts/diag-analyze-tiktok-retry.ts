/**
 * Focused Analyze-only TikTok rehydration retry coverage.
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

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const { classifyYtDlpStderr, YtdlpMetadataError } = await import("../src/services/ytdlp");
  const { isAnalyzeTikTokRehydrationRetryEligible } = await import(
    "../src/services/ytdlpAnalyzeErrors"
  );
  const { fetchMetadataJsonForAnalyze } = await import(
    "../src/services/analyzeTikTokRehydrationRetry"
  );
  const { hostnameIsTikTok } = await import("../src/services/urlSafety");

  assert.equal(hostnameIsTikTok("www.tiktok.com"), true);
  assert.equal(hostnameIsTikTok("vt.tiktok.com"), true);
  assert.equal(hostnameIsTikTok("vm.tiktok.com"), true);
  assert.equal(hostnameIsTikTok("www.youtube.com"), false);

  assert.equal(classifyYtDlpStderr(REHYDRATION_STDERR), "tiktok_rehydration");

  // Eligibility matrix
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    true,
    "TikTok rehydration attempt 1 eligible"
  );
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 2,
    }),
    false,
    "attempt 2 never eligible"
  );
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "unsupported_url",
      attempt: 1,
    }),
    false,
    "Unsupported URL: no retry"
  );
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "auth_required",
      attempt: 1,
    }),
    false,
    "login/sensitive: no retry"
  );
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "unknown",
      attempt: 1,
    }),
    false,
    "generic TikTok failure: no retry"
  );
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "www.youtube.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    false,
    "YouTube: no retry even if misclassified"
  );

  const okMeta = {
    id: "diag",
    title: "ok",
    extractor: "TikTok",
    formats: [{ format_id: "1", ext: "mp4", height: 720 }],
  };

  // 1) first fail → retry → success
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
      assert.equal(out.meta.id, "diag");
    }
    assert.equal(calls, 2, "exactly two yt-dlp calls on retry success");
    assert.ok(elapsed < 500, `immediate retry expected; elapsed=${elapsed}ms`);
    console.log(`case1 retry-success OK (elapsedMs=${elapsed})`);
  }

  // 2) first fail → retry → same failure → two attempts, original error
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/2",
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 2);
      assert.equal(out.retryEligible, true);
      assert.equal(out.retryResult, "failure");
      assert.equal(out.error.classification, "tiktok_rehydration");
    }
    assert.equal(calls, 2, "exactly two attempts then fail");
    console.log("case2 retry-fail OK");
  }

  // 3) Unsupported URL → no retry
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/3",
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError("unsupported_url", "ERROR: Unsupported URL");
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 1);
      assert.equal(out.retryEligible, false);
      assert.equal(out.retryResult, "not_attempted");
    }
    assert.equal(calls, 1);
    console.log("case3 unsupported no-retry OK");
  }

  // 4) /photo/ style unsupported → no retry
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/photo/4",
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError(
          "unsupported_url",
          "ERROR: Unsupported URL: https://www.tiktok.com/@x/photo/4"
        );
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 1);
      assert.equal(out.retryEligible, false);
    }
    assert.equal(calls, 1);
    console.log("case4 photo unsupported no-retry OK");
  }

  // 5) login/sensitive → no retry
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/5",
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError("auth_required", "ERROR: Login required");
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 1);
      assert.equal(out.retryEligible, false);
    }
    assert.equal(calls, 1);
    console.log("case5 auth no-retry OK");
  }

  // 6) generic TikTok extraction failure → no retry
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/6",
      "www.tiktok.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError("unknown", "ERROR: [TikTok] something else failed");
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 1);
      assert.equal(out.retryEligible, false);
    }
    assert.equal(calls, 1);
    console.log("case6 generic no-retry OK");
  }

  // 7) YouTube failure → no retry
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.youtube.com/watch?v=abc",
      "www.youtube.com",
      async () => {
        calls += 1;
        throw new YtdlpMetadataError("auth_required", "Sign in to confirm you're not a bot");
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.attempts, 1);
      assert.equal(out.retryEligible, false);
    }
    assert.equal(calls, 1);
    console.log("case7 youtube no-retry OK");
  }

  // 8) successful first TikTok attempt → no extra call
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/8",
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
    assert.equal(calls, 1, "no extra yt-dlp call on first-attempt success");
    console.log("case8 first-success single call OK");
  }

  // 9) retry success returns one meta — caller upserts once (no duplicate fetch side effects)
  {
    let calls = 0;
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/9",
      "www.tiktok.com",
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        return okMeta;
      }
    );
    assert.equal(out.ok, true);
    assert.equal(calls, 2);
    // Single successful outcome object — Analyze continues once to Link upsert.
    if (out.ok) {
      assert.equal(out.meta.extractor, "TikTok");
    }
    console.log("case9 single success outcome (one upsert path) OK");
  }

  // 10) response contract: helper does not invent new error codes / only YtdlpMetadataError
  {
    const out = await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/10",
      "www.tiktok.com",
      async () => {
        throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
      }
    );
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.ok(out.error instanceof YtdlpMetadataError);
      assert.equal(out.error.classification, "tiktok_rehydration");
      assert.equal(out.error.message, "yt-dlp metadata failed");
    }
    console.log("case10 error contract unchanged OK");
  }

  // 11) timing: stage-level wrapper should sum both attempts (caller responsibility)
  {
    const { startPerfTimer } = await import("../src/services/analyzePerf");
    const total = startPerfTimer();
    let calls = 0;
    await fetchMetadataJsonForAnalyze(
      "https://www.tiktok.com/@x/video/11",
      "www.tiktok.com",
      async () => {
        calls += 1;
        await new Promise((r) => setTimeout(r, 20));
        if (calls === 1) {
          throw new YtdlpMetadataError("tiktok_rehydration", REHYDRATION_STDERR.slice(-200));
        }
        return okMeta;
      }
    );
    const totalMs = total.elapsedMs();
    assert.ok(totalMs >= 40, `analyze_total-style timer includes retry; got ${totalMs}`);
    assert.equal(calls, 2);
    console.log(`case11 combined timing OK (totalMs=${Math.round(totalMs)})`);
  }

  console.log("diag:analyze-tiktok-retry OK (11 cases)");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
