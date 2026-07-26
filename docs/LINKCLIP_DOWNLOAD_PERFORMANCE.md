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
2. **TikTok `best`** — mostly Analyze (~3s) + yt-dlp (~3.8–4.3s); ffmpeg **skipped** (non–TikTok-ready path); backend total ~4–4.4s.
3. **TikTok `tiktok_ready`** — was the highest bottleneck (ffmpeg `full_transcode` ~13.4s). **Done — verified in production:** AVC/H.264-preferring selector → `strategy=audio_only`, ffmpeg **1019–1239ms**, `backend_total` **3768–4124ms** (was ffmpeg ~13400ms / `backend_total` ~16566ms).
4. **Analyze** — almost entirely `analyze_ytdlp_metadata` (~2.8–2.9s of ~2.9s total). UI/upsert/qualities ≈ 0–10ms. Mobile `analyze_http` ~3.3s; `analyze_ui_ready` 0ms.
5. **Mobile `cache_finalize`** — ~1.2–2.0s (low priority for now).
6. **Save** — ~0.2–0.4s — not a bottleneck.
7. **Share** — prep ms-scale; prior 5–10s was native sheet / user time — **do not optimize Share**.

## Performance backlog (priority order)

| Priority | Area | Status | Notes |
|----------|------|--------|--------|
| **1** | TikTok-ready `full_transcode` avoidance | **Done — verified in production** | Prefer AVC/H.264 (+ AAC); HE-AACv2 → `audio_only`; see verified timings below |
| **2** | Analyze metadata cost (`--dump-json`) | **Partially mitigated** | Redis short-TTL (60s) Analyze DTO cache + same-process in-flight dedupe shipped; first request still pays full `--dump-json`. Further: progressive UI / lighter metadata |
| **3** | Analyze failure `classification=unknown` | Open — later | Improve yt-dlp stderr → typed classification |
| **4** | Mobile cache finalize (large files) | Low | Streaming-to-disk if bytes grow |
| **5** | Share / Save | **Not active** | Do not change |

## TikTok-ready compatible-format preference (verified)

**Scope:** `YT_DLP_FORMAT_PRIMARY.tiktok_ready` only (`YT_DLP_FORMAT_TIKTOK_READY` in `ytdlp.ts`). **`best` unchanged** — production regression: ffmpeg `strategy=skipped`.

Prefer progressive AVC/H.264 (+ AAC when tagged), then AVC video+audio merge, then the legacy chain:

```text
best[ext=mp4][vcodec^=avc1][acodec^=mp4a]/
best[ext=mp4][vcodec^=avc1]/
best[ext=mp4][vcodec=h264][acodec^=mp4a]/
best[ext=mp4][vcodec=h264]/
bestvideo[ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/
bestvideo[ext=mp4][vcodec^=h264]+bestaudio[ext=m4a]/
bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best
```

- Post-download **ffprobe + normalize still always runs** for TikTok-ready (`remux` / `audio_only` / `full_transcode`).
- If only HEVC (or otherwise incompatible) formats exist, last arms match former behavior → `full_transcode` remains acceptable.
- `availableQualities` still offers `tiktok_ready` whenever `best` is available (no AVC-only gating).
- Worker + file-stream logs are path-free (normalize + `GET /downloads/:id/file` hygiene verified in production).

### Verified production measurements (2026-07)

| Metric | Before (HEVC → full_transcode) | After (h264 + HE-AACv2 → audio_only) |
|--------|--------------------------------|--------------------------------------|
| `ffmpeg` | ~13400ms | **1019–1239ms** |
| `backend_total` | ~16566ms | **3768–4124ms** |
| `strategy` | `full_transcode` | `audio_only` |
| `best` path | `strategy=skipped` | **unchanged** (`skipped`) |

Not every TikTok improves (HEVC-only sources may still `full_transcode`).

## Analyze result cache (60s Redis + in-flight dedupe)

- Key: `analyze:result:v1:{urlHash}` (hash of normalized URL; never log the key/URL).
- TTL: **60 seconds**. Stores the full Analyze JSON DTO (including `availableQualities`).
- Hit: skip `fetchMetadataJson` and Link upsert; still count daily Analyze quota.
- Miss: existing flow + upsert, then cache on **success only** (failures never cached).
- Redis errors: warn and fall through (Analyze must not fail because of cache).
- Invalid cached payload (malformed JSON or bad shape): treat as miss, best-effort Redis `DEL` (`op: "delete_invalid"`; never logs key/URL/payload); DEL failure does not fail Analyze.
- Same-process concurrent identical URLs share one Promise (`analyze_inflight_wait` / `joined` / `joined_failure`). Every HTTP request emits its own `analyze_total` (including failed in-flight followers).
- Perf: `analyze_cache_lookup` with `redis_hit` / `redis_miss` / `redis_error`.

## TikTok-ready full_transcode avoidance — investigation notes (2026-07-26)

Historical investigation that led to the selector above. Normalize rules unchanged:

| Strategy | When | Notes |
|----------|------|--------|
| `full_transcode` | Video missing **or** not `h264` + `yuv420p` + even WxH | HEVC fails video gate → this path |
| `audio_only` | Video OK for copy, audio not AAC-LC (e.g. HE-AAC) | Re-encode audio only |
| `remux` | Video + audio both copy-compatible | `-c copy` + `faststart` |
| `skipped` | **Only** non–`tiktok_ready` video (or audio jobs) | TikTok-ready **never** skips ffmpeg |

Quality tradeoff: may pick lower resolution than HEVC “best” — intentional for social-ready intent.

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

**Recommended next targets:**

1. **Analyze first-hit `--dump-json` cost** — Redis 60s result cache + in-flight dedupe shipped; progressive UI / lighter metadata still open.
2. Analyze failure classification improvements.
3. Large-file cache finalize streaming (if needed).
4. Share/Save — no change.

TikTok-ready `full_transcode` avoidance is **Done — verified in production** (see table above).

## Related

- Investigation context: prior “Download performance investigation” report in chat.
- Fix tracking: `docs/LINKCLIP_FIX_TRACKING.md` (do not mark performance fixes Done until measured + shipped).
