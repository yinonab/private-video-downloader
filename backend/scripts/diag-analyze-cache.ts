/**
 * Analyze short-TTL Redis cache + in-flight dedupe regression checks.
 * Run: npm run diag:analyze-cache
 *
 * Does not call real yt-dlp or Redis — uses injectable seams.
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

type MemRedis = {
  store: Map<string, { value: string; expiresAtMs: number }>;
  getFails: boolean;
  setFails: boolean;
  delFails: boolean;
  getCalls: number;
  setCalls: number;
  delCalls: number;
  lastSetTtl: number | null;
  get(key: string): Promise<string | null>;
  set(key: string, value: string, expiryMode: "EX", ttlSeconds: number): Promise<"OK">;
  del(key: string): Promise<number>;
};

function createMemRedis(): MemRedis {
  const store = new Map<string, { value: string; expiresAtMs: number }>();
  const redis: MemRedis = {
    store,
    getFails: false,
    setFails: false,
    delFails: false,
    getCalls: 0,
    setCalls: 0,
    delCalls: 0,
    lastSetTtl: null,
    async get(key) {
      redis.getCalls += 1;
      if (redis.getFails) throw new Error("redis_get_boom");
      const hit = store.get(key);
      if (!hit) return null;
      if (Date.now() > hit.expiresAtMs) {
        store.delete(key);
        return null;
      }
      return hit.value;
    },
    async set(key, value, expiryMode, ttlSeconds) {
      redis.setCalls += 1;
      if (redis.setFails) throw new Error("redis_set_boom");
      assert.equal(expiryMode, "EX");
      redis.lastSetTtl = ttlSeconds;
      store.set(key, { value, expiresAtMs: Date.now() + ttlSeconds * 1000 });
      return "OK";
    },
    async del(key) {
      redis.delCalls += 1;
      if (redis.delFails) throw new Error("redis_del_boom");
      return store.delete(key) ? 1 : 0;
    },
  };
  return redis;
}

function mockMeta() {
  return {
    id: "diag1",
    title: "Diag Title",
    thumbnail: "https://example.com/t.jpg",
    duration: 12.7,
    extractor: "TikTok",
    formats: [
      { format_id: "1", ext: "mp4", height: 720, width: 1280, vcodec: "h264", acodec: "aac" },
      { format_id: "a", ext: "m4a", vcodec: "none", acodec: "aac" },
    ],
  };
}

function seedCache(redis: MemRedis, key: string, value: string): void {
  redis.store.set(key, { value, expiresAtMs: Date.now() + 60_000 });
}

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
  ensureDiagEnv();

  const {
    analyzeUrl,
    resetAnalyzeInflightForTests,
  } = await import("../src/modules/analyze/analyze.service");
  const { ANALYZE_RESULT_CACHE_TTL_SEC, analyzeResultCacheKey } = await import(
    "../src/services/analyzeResultCache"
  );
  const { hashUrl } = await import("../src/services/hashing");
  const { normalizeUrl } = await import("../src/services/urlSafety");
  const { YtdlpMetadataError } = await import("../src/services/ytdlp");
  const { AppError } = await import("../src/types/errors");
  const { logger } = await import("../src/services/logger");

  const testUrl = "https://www.tiktok.com/@diag/video/1234567890123456789";
  const urlHash = hashUrl(normalizeUrl(testUrl));
  const cacheKey = analyzeResultCacheKey(urlHash);

  let fetchCount = 0;
  let upsertCount = 0;

  const prisma = {
    link: {
      upsert: async () => {
        upsertCount += 1;
        return {};
      },
    },
  } as never;

  const fetchMetadata = async () => {
    fetchCount += 1;
    return mockMeta() as never;
  };

  const assertUrlSafe = async () => {
    /* skip DNS */
  };

  // --- 1) First request: miss, yt-dlp once, upsert once, cache TTL 60
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redis1 = createMemRedis();
  const first = await analyzeUrl(prisma, testUrl, {
    redis: redis1,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(fetchCount, 1);
  assert.equal(upsertCount, 1);
  assert.equal(redis1.setCalls, 1);
  assert.equal(redis1.lastSetTtl, ANALYZE_RESULT_CACHE_TTL_SEC);
  assert.ok(redis1.store.has(cacheKey));
  assert.equal(first.title, "Diag Title");
  assert.ok(Array.isArray(first.availableQualities));
  assert.ok(first.availableQualities.length > 0);

  // --- 2) Second identical within TTL: hit, no yt-dlp, no upsert
  const fetchBeforeHit = fetchCount;
  const upsertBeforeHit = upsertCount;
  const second = await analyzeUrl(prisma, testUrl, {
    redis: redis1,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(fetchCount, fetchBeforeHit);
  assert.equal(upsertCount, upsertBeforeHit);
  assert.equal(second.title, first.title);
  assert.deepEqual(second.availableQualities, first.availableQualities);
  assert.equal(second.url, first.url);

  // --- 3) Cache write failure: Analyze still succeeds
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redisWriteFail = createMemRedis();
  redisWriteFail.setFails = true;
  const writeFailDto = await analyzeUrl(prisma, testUrl, {
    redis: redisWriteFail,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(fetchCount, 1);
  assert.equal(upsertCount, 1);
  assert.equal(writeFailDto.title, "Diag Title");
  assert.equal(redisWriteFail.store.size, 0);

  // --- 4) Cache read failure: normal Analyze still runs
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redisReadFail = createMemRedis();
  redisReadFail.getFails = true;
  const readFailDto = await analyzeUrl(prisma, testUrl, {
    redis: redisReadFail,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(fetchCount, 1);
  assert.equal(upsertCount, 1);
  assert.equal(readFailDto.title, "Diag Title");

  // --- 5) Failed Analyze: no cache entry written
  resetAnalyzeInflightForTests();
  const redisFail = createMemRedis();
  await assert.rejects(
    () =>
      analyzeUrl(prisma, testUrl, {
        redis: redisFail,
        assertUrlSafe,
        fetchMetadata: async () => {
          throw new YtdlpMetadataError("unknown", "diag fail");
        },
      }),
    (e: unknown) => e instanceof AppError
  );
  assert.equal(redisFail.setCalls, 0);
  assert.equal(redisFail.store.size, 0);

  // --- 6) Two concurrent identical requests: yt-dlp once, same DTO, inflight cleared
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redisConc = createMemRedis();
  let releaseFetch!: () => void;
  const fetchGate = new Promise<void>((resolve) => {
    releaseFetch = resolve;
  });
  const slowFetch = async () => {
    fetchCount += 1;
    await fetchGate;
    return mockMeta() as never;
  };
  const p1 = analyzeUrl(prisma, testUrl, {
    redis: redisConc,
    fetchMetadata: slowFetch,
    assertUrlSafe,
  });
  await new Promise((r) => setImmediate(r));
  const p2 = analyzeUrl(prisma, testUrl, {
    redis: redisConc,
    fetchMetadata: slowFetch,
    assertUrlSafe,
  });
  releaseFetch();
  const [a, b] = await Promise.all([p1, p2]);
  assert.equal(fetchCount, 1);
  assert.equal(upsertCount, 1);
  assert.deepEqual(a, b);
  assert.equal(redisConc.setCalls, 1);
  redisConc.store.clear();
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  await analyzeUrl(prisma, testUrl, {
    redis: redisConc,
    fetchMetadata: async () => {
      fetchCount += 1;
      return mockMeta() as never;
    },
    assertUrlSafe,
  });
  assert.equal(fetchCount, 1);

  // --- 7) Concurrent failed Analyze: both reject, inflight cleared, later retry works
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  const redisConcFail = createMemRedis();
  let releaseFail!: () => void;
  const failGate = new Promise<void>((resolve) => {
    releaseFail = resolve;
  });
  const failingFetch = async () => {
    fetchCount += 1;
    await failGate;
    throw new YtdlpMetadataError("unknown", "diag concurrent fail");
  };
  const f1 = analyzeUrl(prisma, testUrl, {
    redis: redisConcFail,
    fetchMetadata: failingFetch,
    assertUrlSafe,
  });
  await new Promise((r) => setImmediate(r));
  const f2 = analyzeUrl(prisma, testUrl, {
    redis: redisConcFail,
    fetchMetadata: failingFetch,
    assertUrlSafe,
  });
  releaseFail();
  const settled = await Promise.allSettled([f1, f2]);
  assert.equal(settled[0]?.status, "rejected");
  assert.equal(settled[1]?.status, "rejected");
  assert.equal(fetchCount, 1);
  assert.equal(redisConcFail.setCalls, 0);

  fetchCount = 0;
  const retry = await analyzeUrl(prisma, testUrl, {
    redis: redisConcFail,
    fetchMetadata: async () => {
      fetchCount += 1;
      return mockMeta() as never;
    },
    assertUrlSafe,
  });
  assert.equal(fetchCount, 1);
  assert.equal(retry.title, "Diag Title");

  // --- 8) Malformed cached JSON: miss, DEL once, fresh succeeds, then cached
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redisMalformed = createMemRedis();
  seedCache(redisMalformed, cacheKey, "{not-json");
  const afterMalformed = await analyzeUrl(prisma, testUrl, {
    redis: redisMalformed,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(redisMalformed.delCalls, 1);
  assert.equal(fetchCount, 1);
  assert.equal(upsertCount, 1);
  assert.equal(afterMalformed.title, "Diag Title");
  assert.equal(redisMalformed.setCalls, 1);
  assert.ok(redisMalformed.store.has(cacheKey));
  const cachedAfter = JSON.parse(redisMalformed.store.get(cacheKey)!.value) as { title?: string };
  assert.equal(cachedAfter.title, "Diag Title");

  // --- 9) Invalid but parseable shape: miss, DEL once
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redisBadShape = createMemRedis();
  seedCache(
    redisBadShape,
    cacheKey,
    JSON.stringify({ url: "https://example.com/x", platform: "tiktok", title: "x" })
  );
  const afterBadShape = await analyzeUrl(prisma, testUrl, {
    redis: redisBadShape,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(redisBadShape.delCalls, 1);
  assert.equal(fetchCount, 1);
  assert.equal(afterBadShape.title, "Diag Title");

  // --- 10) Redis DEL failure: fresh Analyze still succeeds
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  upsertCount = 0;
  const redisDelFail = createMemRedis();
  redisDelFail.delFails = true;
  seedCache(redisDelFail, cacheKey, "{broken");
  const afterDelFail = await analyzeUrl(prisma, testUrl, {
    redis: redisDelFail,
    fetchMetadata,
    assertUrlSafe,
  });
  assert.equal(redisDelFail.delCalls, 1);
  assert.equal(fetchCount, 1);
  assert.equal(upsertCount, 1);
  assert.equal(afterDelFail.title, "Diag Title");

  // --- 11) Concurrent failed follower: own analyze_total, inflight cleared, retry ok
  resetAnalyzeInflightForTests();
  fetchCount = 0;
  let analyzeTotalFailureLogs = 0;
  let joinedFailureLogs = 0;
  const origInfo = logger.info.bind(logger);
  (logger as { info: typeof logger.info }).info = ((...args: unknown[]) => {
    const fields = args[0];
    if (fields && typeof fields === "object" && "stage" in fields) {
      const f = fields as { stage?: string; result?: string };
      if (f.stage === "analyze_total" && f.result === "failure") analyzeTotalFailureLogs += 1;
      if (f.stage === "analyze_inflight_wait" && f.result === "joined_failure") joinedFailureLogs += 1;
    }
    return origInfo(...(args as Parameters<typeof logger.info>));
  }) as typeof logger.info;

  const redisFollowerFail = createMemRedis();
  let releaseFollowerFail!: () => void;
  const followerFailGate = new Promise<void>((resolve) => {
    releaseFollowerFail = resolve;
  });
  const failingFetch2 = async () => {
    fetchCount += 1;
    await followerFailGate;
    throw new YtdlpMetadataError("unknown", "diag follower fail");
  };
  const ff1 = analyzeUrl(prisma, testUrl, {
    redis: redisFollowerFail,
    fetchMetadata: failingFetch2,
    assertUrlSafe,
  });
  await new Promise((r) => setImmediate(r));
  const ff2 = analyzeUrl(prisma, testUrl, {
    redis: redisFollowerFail,
    fetchMetadata: failingFetch2,
    assertUrlSafe,
  });
  releaseFollowerFail();
  const followerSettled = await Promise.allSettled([ff1, ff2]);
  (logger as { info: typeof logger.info }).info = origInfo;

  assert.equal(followerSettled[0]?.status, "rejected");
  assert.equal(followerSettled[1]?.status, "rejected");
  assert.equal(fetchCount, 1);
  assert.equal(joinedFailureLogs, 1);
  // Leader + follower each emit analyze_total failure
  assert.equal(analyzeTotalFailureLogs, 2);
  assert.equal(redisFollowerFail.setCalls, 0);

  fetchCount = 0;
  const retryAfterFollower = await analyzeUrl(prisma, testUrl, {
    redis: redisFollowerFail,
    fetchMetadata: async () => {
      fetchCount += 1;
      return mockMeta() as never;
    },
    assertUrlSafe,
  });
  assert.equal(fetchCount, 1);
  assert.equal(retryAfterFollower.title, "Diag Title");

  console.log("diag:analyze-cache OK (11/11 cases)");
}

main().catch((err) => {
  console.error("diag:analyze-cache FAILED", err);
  process.exitCode = 1;
});
