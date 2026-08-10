/**
 * Focused download-worker TikTok transient extraction retry coverage (Rank 4).
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
const UNEXPECTED_STDERR = "ERROR: [TikTok] Unexpected response from webpage request";

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const { classifyYtDlpStderr } = await import("../src/services/ytdlp");
  const {
    isTikTokTransientExtractionFailure,
    isTikTokTransientExtractionRetryEligible,
    isWorkerTikTokRehydrationRetryEligible,
    TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS,
  } = await import("../src/services/ytdlpAnalyzeErrors");
  const { runPrimaryYtDlpWithTikTokRehydrationRetry } = await import(
    "../src/services/downloadTikTokRehydrationRetry"
  );

  assert.equal(TIKTOK_TRANSIENT_EXTRACTION_MAX_ATTEMPTS, 3);
  assert.equal(classifyYtDlpStderr(REHYDRATION_STDERR), "tiktok_rehydration");
  assert.equal(
    classifyYtDlpStderr(UNEXPECTED_STDERR, { urlHost: "www.tiktok.com" }),
    "tiktok_webpage_unexpected"
  );
  assert.equal(
    classifyYtDlpStderr(UNEXPECTED_STDERR, { urlHost: "www.instagram.com" }),
    "unknown"
  );

  assert.equal(isTikTokTransientExtractionFailure("tiktok_rehydration"), true);
  assert.equal(isTikTokTransientExtractionFailure("tiktok_webpage_unexpected"), true);
  assert.equal(isTikTokTransientExtractionFailure("unknown"), false);

  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_webpage_unexpected",
      attempt: 1,
    }),
    true
  );
  assert.equal(
    isTikTokTransientExtractionRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 2,
    }),
    true
  );
  assert.equal(
    isWorkerTikTokRehydrationRetryEligible({
      urlHost: "www.tiktok.com",
      classification: "tiktok_rehydration",
      attempt: 3,
    }),
    false
  );

  let lastClass: ReturnType<typeof classifyYtDlpStderr> = "unknown";
  let partialClears = 0;

  // 13a) rehydration → success (2)
  {
    let calls = 0;
    partialClears = 0;
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
        return 0;
      },
      classifyAfterAttempt: () => lastClass,
      clearPartials: async () => {
        partialClears += 1;
      },
    });
    assert.equal(out.code, 0);
    assert.equal(out.attempts, 2);
    assert.equal(out.retryResult, "success");
    assert.equal(calls, 2);
    assert.equal(partialClears, 1);
    console.log("case13a rehydration→success OK");
  }

  // 13b) unexpected → success (2)
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        if (calls === 1) {
          lastClass = "tiktok_webpage_unexpected";
          return 1;
        }
        return 0;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(out.attempts, 2);
    assert.equal(out.code, 0);
    assert.equal(calls, 2);
    console.log("case13b unexpected→success OK");
  }

  // 14) attempt 3 success — one outcome (FileAsset/ffmpeg once at caller)
  {
    let calls = 0;
    partialClears = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      jobId: "diag-job-3",
      runAttempt: async () => {
        calls += 1;
        if (calls === 1) {
          lastClass = "tiktok_rehydration";
          return 1;
        }
        if (calls === 2) {
          lastClass = "tiktok_webpage_unexpected";
          return 1;
        }
        return 0;
      },
      classifyAfterAttempt: () => lastClass,
      clearPartials: async () => {
        partialClears += 1;
      },
    });
    assert.equal(out.code, 0);
    assert.equal(out.attempts, 3);
    assert.equal(calls, 3);
    assert.equal(partialClears, 2, "partials cleared before attempts 2 and 3");
    console.log("case14 attempt3 success (single outcome) OK");
  }

  // 15) attempt 3 failure — helper returns once; terminal Slack/EventLog is caller once
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = calls === 2 ? "tiktok_webpage_unexpected" : "tiktok_rehydration";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(out.code, 1);
    assert.equal(out.attempts, 3);
    assert.equal(out.retryResult, "failure");
    assert.equal(calls, 3);
    console.log("case15 triple transient fail OK");
  }

  // 16) unsupported/photo — no retry
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
    console.log("case16 unsupported no-retry OK");
  }

  // 17) generic unknown — no retry
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
    console.log("case17 unknown no-retry OK");
  }

  // 18) format_unavailable — unchanged (outside helper)
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
    assert.equal(out.code, 1);
    console.log("case18 format_unavailable not in transient family OK");
  }

  // 19) non-TikTok — no retry
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
    console.log("case19 non-TikTok no-retry OK");
  }

  // Hard stop: transient → hard → no third
  {
    let calls = 0;
    const out = await runPrimaryYtDlpWithTikTokRehydrationRetry({
      urlHost: "www.tiktok.com",
      platformLabel: "tiktok",
      runAttempt: async () => {
        calls += 1;
        lastClass = calls === 1 ? "tiktok_webpage_unexpected" : "auth_required";
        return 1;
      },
      classifyAfterAttempt: () => lastClass,
    });
    assert.equal(calls, 2);
    assert.equal(out.attempts, 2);
    console.log("case-hardstop transient→auth stop at 2 OK");
  }

  // First success
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
    assert.equal(calls, 1);
    assert.equal(out.attempts, 1);
    console.log("case-first-success OK");
  }

  // Max 3 — never a fourth primary call
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
    assert.equal(calls, 3);
    console.log("case-max3 never fourth OK");
  }

  // 23) BullMQ attempts remains 1
  const fs = await import("node:fs/promises");
  const dlService = await fs.readFile(
    path.join(backendRoot, "src/modules/downloads/download.service.ts"),
    "utf8"
  );
  assert.match(dlService, /attempts:\s*1/);
  console.log("case23 BullMQ attempts:1 still in download.service OK");

  console.log("diag:download-tiktok-retry OK (Rank 4)");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
