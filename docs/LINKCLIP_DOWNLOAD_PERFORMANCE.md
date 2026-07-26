# LinkClip download performance — instrumentation & benchmark

This document explains how to collect wall-clock timings after the performance instrumentation pass. **No optimizations are implied here** — measure first.

## Log prefixes

| Layer | Prefix | Where |
|--------|--------|--------|
| Backend | `[Perf][Download]` | API + download worker logs (pino) |
| Mobile | `[Perf][MobileDownload]` | Debug builds only (`kDebugMode`) |

**Never logged:** raw URLs, tokens, cookies, secrets, auth headers.

## Backend stages

| `stage=` | Meaning |
|----------|---------|
| `analyze` | `POST /analyze` wall time |
| `analyze_failed` | Analyze threw (duration until failure) |
| `job_create` | `POST /downloads` create/cache-hit |
| `queue_wait` | Job `createdAt` → worker picked / marked running |
| `ytdlp` | Source media download (yt-dlp or Facebook direct) |
| `ffmpeg` | TikTok-ready normalize, or `strategy=skipped` |
| `running_to_done` | Worker running → done |
| `backend_total` | Job create → done |

Useful fields: `jobId`, `platform`, `quality`, `formatSelector`, `mergeLikely`, `strategy`, `bytes`, `mime`, `ext`, `durationMs`, `result`.

## Mobile stages (debug)

| `stage=` | Meaning |
|----------|---------|
| `create_job` | `POST /downloads` client RTT |
| `poll_until_backend_done` | After create/open until status `done` |
| `cache_finalize` | `reused_cache` or `downloaded_to_cache` (+ optional `mbps`) |
| `save_to_device` | `already_published` / `published_to_device` |
| `share` / `open` | Used cache path |

## How to collect logs

### Backend (local Docker / SSH)

```bash
# Example: follow worker + API logs and filter
docker compose -f backend/docker-compose.yml logs -f api worker 2>&1 | findstr /C:"[Perf][Download]"
```

On Linux/macOS:

```bash
docker compose -f backend/docker-compose.yml logs -f api worker 2>&1 | grep '\[Perf\]\[Download\]'
```

### Mobile

1. Install a **debug** APK (`flutter build apk --debug`).
2. `adb logcat | findstr /C:"[Perf][MobileDownload]"` (Windows) or `adb logcat | grep '\[Perf\]\[MobileDownload\]'`.

Release builds omit mobile perf lines (`kDebugMode`).

## Benchmark matrix

For each row, paste a **representative** link (do not paste secrets). Prefer recording URL **category** only in notes.

| # | Platform | Quality | Notes |
|---|----------|---------|--------|
| 1 | TikTok | `best` | Short vertical |
| 2 | TikTok | `tiktok_ready` | Same or similar clip |
| 3 | Facebook | `best` | |
| 4 | Instagram | `best` | |
| 5 | YouTube | `best` or `720p` | Only if stable in your env |

### Per-run sheet

Copy one block per run:

```text
runId:
platform:
quality:
analyze_ms:
job_create_ms:
queue_wait_ms:
ytdlp_ms:
ytdlp_bytes:
ytdlp_mergeLikely:
ffmpeg_ms:
ffmpeg_strategy:
backend_total_ms:
mobile_create_job_ms:
mobile_poll_until_done_ms:
mobile_cache_finalize_ms:
mobile_cache_result:
mobile_cache_bytes:
mobile_save_ms:
mobile_save_result:
total_to_ready_approx:   # backend_total + cache_finalize (or poll_until_done + cache if clearer)
total_to_saved_approx:   # total_to_ready + save
```

## Interpreting results

1. If **`ytdlp`** ≫ other stages → source download/merge dominates; consider format-selection experiments later.
2. If **`ffmpeg`** high and `strategy=full_transcode` → TikTok-ready normalize dominates for that path.
3. If **`cache_finalize`** ≫ for large `bytes` → mobile transfer / RAM buffer dominates.
4. If **`queue_wait`** high → worker concurrency / load.

**Next step after collecting data:** identify the highest-duration stage; only then design an optimization.

## Related

- Investigation context: prior “Download performance investigation” report in chat.
- Fix tracking: `docs/LINKCLIP_FIX_TRACKING.md` (do not mark performance fixes Done until measured + shipped).
