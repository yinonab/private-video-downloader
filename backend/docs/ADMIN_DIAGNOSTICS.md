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

## CLI: YouTube baseline matrix (`npm run diag:youtube-matrix`)

Separate from **`diag:runtime`** (toolchain presence) and **`GET /admin/diagnostics?deep=true`** (optional single-URL API probe). This script runs **controlled, metadata-only** yt-dlp analyze probes against a **small** URL set and prints a compact classification table.

### Purpose

- Baseline YouTube reliability checks (auth/bot, geo, formats, network) using the **same production metadata path** as `POST /analyze` (`fetchMetadataJson` + temp cookies copy).
- **Does not download media** (`--skip-download` / `--dump-json` only).
- Intended for **manual, infrequent** operator use — not for cron loops or high-volume testing.

### URL input (precedence)

1. **`YOUTUBE_DIAG_URLS_FILE`** — path to a text file (one URL per line; `#` comments ignored).
2. **`YOUTUBE_DIAG_URLS`** — comma- or newline-separated URLs (appended after file URLs, deduplicated).
3. If **neither** is set → one built-in **public smoke URL** only (single run).

When a custom list is supplied, URLs are capped at **`YOUTUBE_DIAG_MAX_URLS`** (default **5**). The default smoke run always uses **exactly one** URL.

### Other env

| Variable | Meaning |
|----------|---------|
| **`YOUTUBE_DIAG_MAX_URLS`** | Max URLs when a list is provided (default `5`) |
| **`YOUTUBE_DIAG_DELAY_MS`** | Pause between URLs (default `2000` when >1 URL) |
| **`YOUTUBE_DIAG_VERBOSE=1`** | Print **redacted** stderr tails on failures |
| **`COOKIES_FILE`** | Same as production — probed via temp writable copy, never passed directly |

### Example

```bash
cd backend
# Single default smoke (1 URL)
npm run diag:youtube-matrix

# Custom list from env (capped at 5)
YOUTUBE_DIAG_URLS="https://www.youtube.com/watch?v=…,https://youtu.be/…" npm run diag:youtube-matrix

# From file with verbose redacted stderr
YOUTUBE_DIAG_URLS_FILE=./secrets/youtube-diag-urls.txt YOUTUBE_DIAG_VERBOSE=1 npm run diag:youtube-matrix
```

### Output columns

`idx`, `host`, `videoId`, `mode` (`analyze`), `cookies`, `tempCookie`, `poEnabled`, `poUsed`, `poClient`, `providerOk`, `classification`, `code`, `durationMs`.

When **`YTDLP_PO_TOKEN_ENABLED=false`** (default), `poEnabled`/`poUsed` are `no` and no PO extractor args are added — behavior matches cookies-only production.

Classifications: `success`, `auth_required`, `geo_restricted`, `no_formats_found`, `format_unavailable`, `network_or_proxy`, `unknown`.

### Before/after PO comparison

```bash
# Baseline (PO disabled)
YTDLP_PO_TOKEN_ENABLED=false \
YOUTUBE_DIAG_URLS_FILE=/tmp/youtube-diag-urls.txt \
YOUTUBE_DIAG_MAX_URLS=5 YOUTUBE_DIAG_DELAY_MS=2500 \
npm run diag:youtube-matrix

# PO enabled (requires provider + plugin)
YTDLP_PO_TOKEN_ENABLED=true \
YOUTUBE_DIAG_URLS_FILE=/tmp/youtube-diag-urls.txt \
YOUTUBE_DIAG_MAX_URLS=5 YOUTUBE_DIAG_DELAY_MS=2500 \
npm run diag:youtube-matrix
```

Example URL list template: `backend/scripts/fixtures/youtube-diag-urls.example.txt`.

### Security

- Never prints cookie values, cookie file contents, PO tokens, or proxy credentials.
- Does not print full URLs in the table (host + video id only).
- Internal yt-dlp failure logs are **suppressed** during matrix runs unless **`YOUTUBE_DIAG_VERBOSE=1`**.
- Full stderr only with **`YOUTUBE_DIAG_VERBOSE=1`**, and sensitive fragments are redacted.

## CLI: YouTube PO Token spike (`npm run diag:youtube-pot`)

Validates **optional** PO Token Provider configuration before enabling in production.

### Provider

Uses **[bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)** (yt-dlp maintainer–maintained):

- **Plugin:** `pip install bgutil-ytdlp-pot-provider` (in API/worker Docker image).
- **HTTP server (recommended):** `brainicism/bgutil-ytdlp-pot-provider` Docker image on port **4416**.
- **yt-dlp version:** `2025.05.22+` (satisfied by image pip install).

When enabled, yt-dlp receives:

- `--extractor-args youtube:player_client=<YTDLP_PO_TOKEN_CLIENT>` (default `mweb`)
- `--extractor-args youtubepot-bgutilhttp:base_url=<YTDLP_PO_TOKEN_PROVIDER_URL>`

### Config (disabled by default)

| Variable | Default | Meaning |
|----------|---------|---------|
| **`YTDLP_PO_TOKEN_ENABLED`** | `false` | Master switch — when false, no PO args, no provider contact |
| **`YTDLP_PO_TOKEN_PROVIDER_URL`** | empty → `http://127.0.0.1:4416` when enabled | bgutil HTTP server base URL |
| **`YTDLP_PO_TOKEN_CLIENT`** | `mweb` | YouTube innertube client (per PO Token Guide) |
| **`YTDLP_PO_TOKEN_TIMEOUT_MS`** | `8000` | Provider reachability probe timeout |
| **`YTDLP_PO_TOKEN_MODE`** | `server` | `server` (HTTP) or `script` |
| **`YTDLP_PO_TOKEN_CACHE_ENABLED`** | `true` | Documented; provider handles caching |

### Docker

Optional compose service (profile **`pot`** — not started by default):

```bash
docker compose -f docker-compose.prod.yml --profile pot up -d bgutil-pot
```

Set `YTDLP_PO_TOKEN_PROVIDER_URL=http://bgutil-pot:4416` in `.env.production` when enabling.

### diag:youtube-pot behavior

1. Prints config + plugin install + provider reachability.
2. Exits with error if **enabled** but plugin/provider unavailable.
3. Runs one smoke metadata test (or URL list when enabled).
4. Reuses **`YOUTUBE_DIAG_*`** env vars for URL input.

### Related CLI checks

- **`npm run diag:runtime`** — yt-dlp/ffmpeg/node/cookies **presence** (no YouTube HTTP).
- **`npm run diag:ytdlp-classify`** — offline stderr → classification regression (no network).
- **`npm run diag:youtube-matrix`** — baseline matrix with optional PO columns.

## Related endpoints

- **`GET /health`** — lightweight public liveness (unchanged)
- **`GET /admin/health`** — shorter admin health (Postgres + Redis + yt-dlp version)
