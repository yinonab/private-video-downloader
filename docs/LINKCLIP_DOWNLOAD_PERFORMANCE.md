# LinkClip download performance — instrumentation & benchmark

This document explains how to collect wall-clock timings after the performance instrumentation pass. **No optimizations are implied here** — measure first.

## Log prefixes

| Layer | Prefix | Where |
|--------|--------|--------|
| Backend download | `[Perf][Download]` | API + download worker logs (pino) |
| Backend analyze | `[Perf][Analyze]` | `POST /analyze` sub-stages (pino) |
| Mobile | `[Perf][MobileDownload]` | Debug builds only (`kDebugMode`) |

**Never logged:** raw URLs, tokens, cookies, secrets, auth headers.

## Backend stages

| `stage=` | Meaning |
|----------|---------|
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
| `open` | Used cache path (includes OpenFilex await) |
| `share_tap` | User tapped Share |
| `share_validate_cache_start` / `_done` | Descriptor + file validate (`cacheValid`, optional `bytes`) |
| `share_prepare_xfile_start` / `_done` | Build `XFile` from internal cache path |
| `share_native_call_start` / `_return` | Immediately before/after `Share.shareXFiles` (return includes sheet open + user dismiss/pick) |
| `share_total` | Tap → after native call returns (`result=shared_cache_includes_native_sheet_return`) |
| `analyze_http` | Client RTT for `POST /analyze` |
| `analyze_ui_ready` | Response received → quality selector state set |

**Share interpretation:** If `share_native_call_start` is soon after `share_tap`, but `share_native_call_return` / `share_total` are large, the delay is Android share sheet / user interaction — not LinkClip preparation. If `share_native_call_start` itself is delayed by seconds, investigate pre-native Share path next.

## Analyze sub-stage benchmark

Backend prefix: `[Perf][Analyze]`. Instrumentation only — no analyze cache / yt-dlp command changes yet.

| `stage=` | Meaning |
|----------|---------|
| `analyze_request_received` | Route accepted body (marker; `durationMs=0`) |
| `analyze_platform_detect` | Normalize URL / safety / Threads block |
| `analyze_ytdlp_metadata` | `fetchMetadataJson` / `--dump-json` (or failure duration) |
| `analyze_parse_metadata` | Title / thumb / duration / platform from meta |
| `analyze_qualities` | `computeAvailableQualities` |
| `analyze_link_upsert` | Prisma `Link` write-through |
| `analyze_total` | Full `analyzeUrl` wall time (`result=success` / `failure` + `classification`) |

Safe optional fields: `platform`, `urlHost`, `formatCount`, `qualityCount`, `thumbnailPresent`, `cacheHit=false`, `result`, `classification`.

### Fields to collect per run

```text
platform:
analyze_total_ms:
analyze_ytdlp_metadata_ms:
analyze_qualities_ms:
analyze_link_upsert_ms:
mobile_analyze_http_ms:
formatCount:
qualityCount:
thumbnailPresent:
result:   # success | failure
classification:  # on failure only
```

### Matrix

| # | Platform | Clip | Notes |
|---|----------|------|--------|
| 1 | TikTok | short | |
| 2 | TikTok | longer | |
| 3 | Instagram | | |
| 4 | Facebook | | |
| 5 | YouTube | if stable | |

**Hypothesis to confirm:** `analyze_ytdlp_metadata` ≈ `analyze_total` for TikTok (~3s); other stages should be small.

Filter examples:

```bash
# Backend
docker compose -f backend/docker-compose.yml logs -f api 2>&1 | findstr /C:"[Perf][Analyze]"

# Mobile (debug APK)
adb logcat | findstr /C:"[Perf][MobileDownload]" | findstr /C:"analyze_"
```

## First benchmark conclusions (2026-07)

Measured TikTok runs (instrumentation only; **no optimizations Done**):

1. **Queue / job create** — not bottlenecks (~tens of ms).
2. **TikTok `best`** — mostly Analyze (~3s) + yt-dlp (~3.8s); ffmpeg skipped; backend total ~3.9s; file response ~0.56s.
3. **TikTok `tiktok_ready`** — slower mainly because HEVC → ffmpeg `full_transcode` (~5.2s); backend total ~9.3s.
4. **Mobile `cache_finalize`** — ~2s in first sample (Stage B transfer).
5. **Save to device** — fast (~0.4s).
6. **Share (~7–10s with `shared_cache`)** — **suspicious under the old single timer**, which wrapped `Share.shareXFiles` until it returned. Use the split Share stages above before treating Share as a LinkClip bottleneck.

## How to collect logs

### Backend (local Docker / SSH)

```bash
# Example: follow worker + API logs and filter
docker compose -f backend/docker-compose.yml logs -f api worker 2>&1 | findstr /C:"[Perf][Download]"
docker compose -f backend/docker-compose.yml logs -f api 2>&1 | findstr /C:"[Perf][Analyze]"
```

On Linux/macOS:

```bash
docker compose -f backend/docker-compose.yml logs -f api worker 2>&1 | grep '\[Perf\]\[Download\]'
docker compose -f backend/docker-compose.yml logs -f api 2>&1 | grep '\[Perf\]\[Analyze\]'
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
5. For **Share**: compare time to `share_native_call_start` vs `share_native_call_return` (see Share interpretation above).

**Recommended next targets (not implemented):**

- If Share prep is fast → next backend target is TikTok-ready `full_transcode` avoidance when safe.
- If Share prep is slow before native → optimize pre-native Share path only.
- If `cache_finalize` grows with larger files → later: true streaming-to-disk instead of full byte buffering.

**Next step after collecting data:** identify the highest-duration stage; only then design an optimization. Do not mark performance work Done until measured + shipped.

## Related

- Investigation context: prior “Download performance investigation” report in chat.
- Fix tracking: `docs/LINKCLIP_FIX_TRACKING.md` (do not mark performance fixes Done until measured + shipped).
