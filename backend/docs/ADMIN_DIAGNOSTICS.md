# Admin diagnostics (`GET /admin/diagnostics`)

Internal production snapshot for LinkClip download prerequisites. **Requires admin authentication** (same as other `/admin/*` routes).

## Authentication

Send the configured **`ADMIN_TOKEN`** as a Bearer token:

```bash
curl -sS "https://YOUR_API/admin/diagnostics" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Plain-text summary (SSH / quick checks):

```bash
curl -sS "https://YOUR_API/admin/diagnostics?format=text" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Optional **slow / rate-limit-sensitive** YouTube probe (only runs when env is set):

```bash
# Server must define ADMIN_DIAGNOSTICS_YOUTUBE_TEST_URL (e.g. a stable public Shorts URL)
curl -sS "https://YOUR_API/admin/diagnostics?deep=true" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Response overview

| Field | Meaning |
|-------|---------|
| **`ok`** | `true` only when overall **`status`** is **`healthy`** |
| **`status`** | `healthy` \| `warning` \| `critical` |
| **`shortcuts`** | Fast booleans + disk/file summaries + **`mainWarnings`** (human strings) |
| **`checks`** | Structured sections (`app`, `tools`, `youtubeReadiness`, `cookies`, `storage`, `cleanup`, `database`, `redis`, `queues`, `recentFailures`) |

### Shortcut fields

| Shortcut | Meaning |
|----------|---------|
| **`downloadsReady`** | Storage writable **and** `yt-dlp` **and** `ffmpeg` probes succeeded |
| **`storageOk`** | `STORAGE_DIR` exists and writable probe passed |
| **`cookiesOk`** | `COOKIES_FILE` set, file exists, non-empty, Netscape-shaped (heuristic), readable |
| **`youtubeReady`** | `yt-dlp` OK, Node OK, **`yt-dlp-ejs`** import OK, **`YTDLP_JS_RUNTIME_ARGS`** match expected Node flags |
| **`ytDlpOk`** | `yt-dlp --version` succeeded |
| **`ffmpegOk`** | `ffmpeg -version` succeeded |
| **`nodeJsRuntimeOk`** | `node --version` succeeded |
| **`cleanupConfigured`** | `MEDIA_RETENTION_MINUTES` is a positive number **in this process** (often unset on API container; see cleanup check note) |
| **`diskUsagePercent`** | From `df -Pk` on storage dir, or `null` |
| **`storageFileCount`** | Recursive file count under storage (capped) |
| **`storageUsedHuman`** | From `du -sb` when available |
| **`mainWarnings`** | Short strings e.g. missing cookies, disk high, DB down |

## Status rules (rollup)

- **`critical`**: storage missing/unwritable, **yt-dlp** missing, **PostgreSQL** unreachable, **Redis** unreachable, or disk **≥ 90%**
- **`warning`**: cookies invalid/missing, YouTube readiness incomplete, **ffmpeg/ffprobe** issues, disk **≥ 80%** (below 90%), or other notable probe failures
- **`healthy`**: none of the above

## Privacy / security

The endpoint **never** returns:

- Cookie values or full cookie lines  
- `ADMIN_TOKEN`, `DATABASE_URL`, `REDIS_URL`, raw env dumps  
- Raw CDN URLs from jobs  

Paths are **redacted** unless they look like standard Docker paths (`/app/storage`, `/app/secrets/...`).

## Common warnings → what to do

| Warning | Action |
|---------|--------|
| **COOKIES_FILE is missing** | Set `COOKIES_FILE` to the mounted Netscape cookies path (e.g. `/app/secrets/cookies/global.txt`) |
| **Cookies file does not look like valid Netscape** | Export cookies as Netscape format; ensure non-empty tab-separated rows |
| **yt-dlp-ejs is not installed** | Rebuild image / run `pip install "yt-dlp[default,curl-cffi]"` (see Dockerfile) |
| **Node.js runtime is missing** | Use Node-based API image; ensure `node` on `PATH` |
| **YouTube JS runtime / yt-dlp-ejs readiness** | Install **`yt-dlp[default]`**, ensure app passes `--no-js-runtimes --js-runtimes node` (see `YTDLP_JS_RUNTIME_ARGS`) |
| **Storage is not writable** | Fix `STORAGE_DIR` permissions / volume mount |
| **Disk usage high** | Expand disk or prune `/app/storage`; cleanup service uses `MEDIA_RETENTION_MINUTES` |
| **Database / Redis down** | Fix `DATABASE_URL` / `REDIS_URL` connectivity, containers, firewall |

## Skipped / partial checks

- **Deep YouTube**: skipped unless `?deep=true` **and** `ADMIN_DIAGNOSTICS_YOUTUBE_TEST_URL` is set (avoids rate limits).
- **Cleanup container**: API only reports env `MEDIA_RETENTION_MINUTES`; it cannot see sibling Docker containers without Docker socket.
- **EventLog table**: not summarized yet (optional future enhancement).
- **Queue metrics**: if BullMQ introspection throws, section status is **`skipped`**.
- **Recent failures**: if Prisma query throws, section status is **`skipped`**.

## Related endpoints

- **`GET /health`** — lightweight public liveness (unchanged)
- **`GET /admin/health`** — shorter admin health (Postgres + Redis + yt-dlp version)
