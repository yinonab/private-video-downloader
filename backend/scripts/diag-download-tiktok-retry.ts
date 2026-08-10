/**
 * Focused download-worker TikTok rehydration retry coverage (Rank 3).
 * Run: npm run diag:download-tiktok-retry
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
  "ERROR: [TikTok] 123: Unable to extract universal data for rehydration; please report this issue";

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const { classifyYtDlpStderr } = await import("../src/services/ytdlp");
  const {
    isWorkerTikTokRehydrationRetryEligible,
    isAnalyzeTikTokRehydrationRetryEligible,
  } = await import("../src/services/ytdlpAnalyzeErrors");
  const { runPrimaryYtDlpWithTikTokRehydrationRetry } = await import(
    "../src/services/downloadTikTokRehydrationRetry"
  );

  assert.equal(classifyYtDlpStderr(REHYDRATION_STDERR), "tiktok_rehydration");

  assert.equal(
    isWorkerTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    true
  );
  assert.equal(
    isWorkerTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 2,
    }),
    false
  );
  assert.equal(
    isWorkerTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "unsupported_url",
      attempt: 1,
    }),
    false
  );
  assert.equal(
    isWorkerTikTokRehydrationRetryEligible({
      urlHost: "www.youtube.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    false
  );
  // Analyze Rank 2 eligibility still matches worker gate
  assert.equal(
    isAnalyzeTikTokRehydrationRetryEligible({
      urlHost: "vt.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 1,
    }),
    true
  );

  let lastClass: ReturnType<typeof classifyYtDlpStderr> = "unknown";
  let partialClears = 0;

  // 1) rehydration → retry success
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      jobId: "diag-job-1",
      runAttempt: async () => {
        calls += 1;
        if (calls === 1) {
          lastClass = "tiktok_rehydration";
          return 1;
        }
        lastClass = "unknown";
        return 0;
      },
      classifyAfterAttempt: () => lastClass,
      clearPartials: async () => {
        partialClears += 1;
      },
    });
    assert.equal(out.code, 0);
    assert.equal(out.attempts, 2);
    assert.equal(out.retryEligible, true);
    assert.equal(out.retryResult, "success");
    assert.equal(calls, 2);
    assert.equal(partialClears, 1, "partials cleared before retry");
    console.log("case1 retry-success OK");
  }

  // 2) rehydration → retry fail → exactly 2 attempts
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "tiktok_rehydration";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(out.code, 1);
    assert.equal(out.attempts, 2);
    assert.equal(out.retryResult, "failure");
    assert.equal(calls, 2);
    console.log("case2 retry-fail OK (exactly 2 attempts)");
  }

  // 3) first success → one call
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        return 0;
      },
      classifyAfterAttempt: () => "unknown",
    });
    assert.equal(out.code, 0);
    assert.equal(out.attempts, 1);
    assert.equal(out.retryResult, "not_attempted");
    assert.equal(calls, 1);
    console.log("case3 first-success single call OK");
  }

  // 4) unsupported → no retry
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "unsupported_url";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(out.attempts, 1);
    assert.equal(out.retryEligible, false);
    assert.equal(calls, 1);
    console.log("case4 unsupported no-retry OK");
  }

  // 5) photo/unsupported style
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "unsupported_url";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 1);
    assert.equal(out.retryEligible, false);
    console.log("case5 photo/unsupported no-retry OK");
  }

  // 6) auth
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "auth_required";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 1);
    assert.equal(out.retryEligible, false);
    console.log("case6 auth no-retry OK");
  }

  // 7) generic unknown
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "unknown";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 1);
    assert.equal(out.retryEligible, false);
    console.log("case7 generic no-retry OK");
  }

  // 8) format_unavailable — helper does not retry; format fallback stays outside
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "format_unavailable";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 1);
    assert.equal(out.retryEligible, false);
    assert.equal(out.code, 1);
    console.log("case8 format_unavailable not treated as rehydration retry OK");
  }

  // 9) YouTube
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.youtube.com",
      platformLabel: "youtube",
      runAttempt: async () => {
        calls += 1;
        lastClass = "tiktok_rehydration";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 1);
    assert.equal(out.retryEligible, false);
    console.log("case9 youtube no-retry OK");
  }

  // 10) retry success — single outcome (caller runs FileAsset/ffmpeg once)
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "vt.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        if (calls === 1) {
          lastClass = "tiktok_rehydration";
          return 1;
        }
        return 0;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(out.code, 0);
    assert.equal(out.attempts, 2);
    assert.equal(calls, 2);
    // One successful code — worker continues once past yt-dlp block
    console.log("case10 single success outcome (no duplicate post-ytdlp path) OK");
  }

  // 11) max 2 — never a third primary call
  {
    let calls = 0;
    await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = "tiktok_rehydration";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 2);
    assert.equal(
      isWorkerTikTokRehydrationRetryEligible({
        urlHost: "www.tiktok.com",
        classification: "tiktok_rehydration",
        attempt: 2,
      }),
      false
    );
    console.log("case11 max two primary attempts OK");
  }

  // BullMQ attempts remain a download.service concern — assert source still says 1
  const fs = await import("node:fs/promises");
  const dlService = await fs.readFile(
    path.join(backendRoot, "src/modules/downloads/download.service.ts"),
    "utf8"
  );
  assert.match(dlService, /attempts:\s*1/);
  assert.equal((dlService.match(/attempts:\s*1/g) || []).length >= 1, true);
  console.log("case12 BullMQ attempts:1 still in download.service OK");

  console.log("diag:download-tiktok-retry OK (12 cases)");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
