# LinkClip Project Summary

| Metadata | |
|----------|--|
| **Last updated** | 2026-07-20 |
| **Status** | Android Quick Edit MVP implemented; in QA/polish. |
| **Primary platform** | Android |
| **Backend** | Production Docker Compose deployment (see `backend/docker-compose.prod.yml`, `backend/DEPLOY_HETZNER.md`) |
| **Living document** | **Yes** — update after meaningful project changes (see `docs/DEVELOPMENT_WORKFLOW.md`, `.cursor/rules/linkclip-docs.mdc`). |

Polished technical overview of the **private-video-downloader** / **LinkClip** repository: Flutter Android client, Node/Fastify backend, worker, Postgres, Redis/BullMQ, yt-dlp, ffmpeg, and Docker-based deployment. Use this as a handoff doc for developers or future AI sessions.

**Note:** Treat **`docs/LINKCLIP_PROJECT_SUMMARY.md` as the source of truth** until older docs are synced. Some files (root `README.md` Quick Edit section, header/status in `backend/docs/QUICK_EDIT_ARCHITECTURE.md`, environment-specific notes in `docs/handoff.md`) may lag the codebase; **this summary prioritizes what exists in source today**.

---

## 1. Project Overview

**LinkClip** is an Android-first MVP that lets users **analyze** a shared or pasted video URL, **download** media via a backend worker, **edit** videos from links or from the device (**Downloads** / **Edits** areas on Home), then **open**, **share**, or **save** files locally. **Quick Edit** runs **on the server** (ffmpeg): trim, optional **rotate** (clockwise **90° / 180° / 270°** pixel rotation — **0° omits the op**; from the **Format** panel, not a separate tab), **format** (Fill / Fit+blur; applied **after** rotation), **constant playback speed** (0.5×–2× presets; **1×** omits the op), optional **captions** (Android **Captions / כתוביות** tab — **Auto captions** + **V1.5 styling** + **V2.3 presets** (scrollable chips → same explicit `style` / fontSize / **`fontFamily`** / position / color / offsets in API; **no** preset key) + **V3.2 Style Pack** (XL/XXL sizes, Hebrew-friendly font chips, accent colors purple/mint, creator styles, **Creator Highlight** / **News Headline** presets; mobile preview via `google_fonts`) + **V2.2 fine positioning** (**`offsetX`** / **`offsetY`**, arrows + reset in panel; **`EditCaptionsPreviewOverlay`** on real **`EditVideoPreview`** when Captions tab is active; backend ASS `\an` + **`\pos`** burn-in honors the same offsets, clamped) + **V1.5.1 rendering fixes**: **`extra_small`–`xx_large`** size, top/bottom position, white/yellow/purple/mint, clean/bold/dark-box + **V3.2** creator styles; Docker ships **Noto** + OFL **Heebo/Rubik/Assistant** for ASS burn-in; **`captions`** op only when enabled; Whisper + burned-in MP4 — **requires `OPENAI_API_KEY`** on backend), mute, compress. **No translation, manual caption editor, free font/color pickers, finger-drag positioning, or client-side OpenAI.** **No** flip/mirror, free-angle rotation, or client-side ffmpeg for Quick Edit.

| Layer | Technology |
|-------|------------|
| Mobile | Flutter (`mobile/`), Android MVP |
| API | Node.js, TypeScript, **Fastify** (`backend/src/`) |
| Jobs | **Redis** + **BullMQ** (download queue + edit queue) |
| Database | **PostgreSQL** via **Prisma** |
| Acquisition | **yt-dlp**, **yt-dlp-ejs** (explicit pip in Docker image), **ffmpeg** / **ffprobe** |
| Production deploy | **Docker Compose** (documented for Hetzner VPS + Caddy TLS) |

**Documented production API host:** `https://api.linkclip.win` (see `backend/DEPLOY_HETZNER.md`).

**Alternative hosting:** `docs/render-deploy.md` and root `render.yaml` describe Render-style deployment caveats (especially **shared storage** between API and worker).

---

## 2. Current Production State

Verified **in repository / documented flows** (operators still run their own QA):

| Area | Status |
|------|--------|
| Device registration & device token auth | Implemented (`devices` module, middleware) |
| Analyze (`POST /analyze`) | Implemented + rate limits |
| Downloads (create, poll, file stream, retry patterns) | Implemented |
| Cookies for yt-dlp | Optional `COOKIES_FILE`; validated + writable copy pattern in `ytdlp.ts` |
| Operational Slack alerts | Optional Incoming Webhook (`ALERTS_ENABLED`, `ALERT_CHANNEL=slack`, `SLACK_WEBHOOK_URL`). **All** sanitized analyze + download-worker failures can notify (`analyze_failed`, `download_failed`), plus **critical** Instagram session/rate-limit + optional Facebook `no_mp4_candidates`. Payloads: hostname, context (`analyze` / `download_worker`), classification, error code, optional job/device prefix — **no** raw URLs, stderr, cookies, tokens, or paths. Cooldowns: **critical** `ALERT_COOLDOWN_MINUTES` (default 30), **generic** `ALERT_GENERIC_COOLDOWN_MINUTES` (default 5); keys `alertType|context|host|classification` (in-memory). Test: `cd backend && npm run diag:alert`. See `backend/src/services/alert.service.ts`, `operationalAlerts.ts`. |
| YouTube / JS challenges | Node + `yt-dlp-ejs`; `--no-js-runtimes --js-runtimes node` (`YTDLP_JS_RUNTIME_ARGS`) |
| Admin diagnostics | `GET /admin/diagnostics` (JSON + optional `?format=text`, optional `?deep=true`) — see `backend/docs/ADMIN_DIAGNOSTICS.md` |
| Media cleanup | Separate **cleanup** container; **two-tier** retention on `/app/storage`: `devices/*/uploads/*` uses **`UPLOAD_RETENTION_MINUTES`** (default **120**); all **other** files use **`MEDIA_RETENTION_MINUTES`** (default **30**) — see `backend/docker-compose.prod.yml` |
| Local video uploads | **Phase A/B** APIs + Android **`launchLocalVideoEdit`**. Home surfaces **Edit video** (device) beside **Paste link** (web); **Edits** tab lists **local-only** edited outputs (metadata JSON + **`documents/edits/`** paths), **not** a server list API. Limits **175MB / 7min**; **not** listed on Home downloads. |
| Quick Edit backend | `POST /edits` ( **`sourceDownloadJobId`** *xor* **`sourceUploadId`** + **`operations`** ), **`POST /edits/captions/draft`** (same XOR source + **`operations`**: **`trim`** / **`speed`** only — captions draft), `GET /edits/:id` (optional **`sourceKind`**, **`sourceUploadId`**), `GET /edits/:id/file`, `POST /edits/:id/retry` (`backend/src/modules/edit/`) |
| Quick Edit Android | Home **Paste link** / **Edit video** quick actions + **Downloads** / **Edits** tabs (**Edits** = local edit history: filters, ~500MB display cap, missing-file UX); `EditVideoScreen` (**download** vs **upload** [`EditVideoSourceRef`]), **`launchLocalVideoEdit`**, **`image_picker`** / **`file_picker`**, preview (`EditVideoPreviewSource`), export (`mobile/lib/features/edit/`), `LocalEditHistoryStore` (`mobile/lib/core/edit_history/`) |
| Source expiry / redownload | UI sheet + `forceNew` on recreate download (see §7) |
| Threads | **Blocked** in analyze with explicit error (see §8 / §12) |

**Operational shell aliases** (`linkclip-deploy`, `linkclip-diag`, etc.) appear in informal handoffs; they are **not defined in this git repo** — if present, they live on the operator’s server shell profile.

---

## 3. High-Level Architecture

```text
┌─────────────────┐     HTTPS       ┌──────────────────────────────────────┐
│ Flutter Android │ ─────────────── │ Caddy :443 → Fastify API :3000       │
│ (device token)  │                 │  ├─ /devices, /analyze, /downloads   │
└────────┬────────┘                 │  ├─ /edits, /uploads                 │
         │                          │  └─ /admin/*                         │
         │                          └───────────────┬──────────────────────┘
         │                                          │
         │                                          ├── Postgres
         │                                          ├── Redis (BullMQ)
         │                                          └── Volume: /app/storage
         │                                                          ▲
         │                                                          │
         │                               ┌──────────────────────────┴───────────┐
         │                               │ Worker container (same image)        │
         └───────────────────────────────│  • download worker                   │
                                         │  • edit worker                       │
                                         └──────────────────────────────────────┘
                                         ┌──────────────────────────────────────┐
                                         │ cleanup container (alpine + find)    │
                                         │ deletes files older than retention     │
                                         └──────────────────────────────────────┘
```

- **Storage:** API and worker mount the **same** Docker volume in production Compose so downloads and edit outputs are consistent.
- **Cookies:** Host path `backend/secrets/` mounted read-only at `/app/secrets`; yt-dlp always uses `prepareYtDlpCookiesFile()` — a **unique writable temp copy** (`chmod 600`, per-request cleanup) — never the mounted secrets path directly (see `ytdlp.ts`; probed by admin diagnostics + `diag:runtime`).

---

## 4. Backend Summary

**Layout:** `backend/src/modules/` — `devices`, `analyze`, `downloads`, `edit`, **`uploads`**, `admin`, etc.

### Auth & devices

- Registration: `POST /devices/register` (invite / auto-register controlled by env — see `.env.production.example`).
- Authenticated routes use **device Bearer token** (`authDevice` middleware); context includes `dailyLimit`.

### Analyze

- `POST /analyze` — URL safety (including **Threads** rejection), platform detection, yt-dlp metadata path.
- Rate limiting: **`ANALYZE_DAILY_LIMIT`** (default `200` in example env).
- **DRM-protected sources:** When yt-dlp stderr indicates DRM (e.g. Spotify track URLs), analyze returns HTTP **422**, code **`DRM_PROTECTED`**, with a non-technical English message (no raw stderr). Operational Slack uses classification **`drm_protected`**, host only, same error code. LinkClip does **not** attempt DRM bypass or Spotify track downloads.
- **Source-specific yt-dlp failures (typed analyze errors):** stderr is classified in `ytdlp.ts` (`classifyYtDlpStderr`) and mapped in `ytdlpAnalyzeErrors.ts`. Responses use HTTP **422** with **`error.code`**, optional **`classification`** / **`platform`** in the JSON body (no raw stderr). Flutter shows title + body on the analyze screen via `localizedApiErrorDetail` + `ErrorView.subtitle`.
  - **`YOUTUBE_AUTH_REQUIRED`** — bot challenge / expired YouTube cookies (`auth_required`, platform `youtube`).
  - **`YOUTUBE_GEO_RESTRICTED`** — region-blocked on the server (`geo_restricted`).
  - **`NO_DOWNLOADABLE_FORMATS`** — no video/audio formats (generic hosts).
  - **`FACEBOOK_NO_FORMATS_FOUND`** — Facebook extractor returned no formats (`no_formats_found`, platform `facebook`).
  - Unclassified failures still return **`ANALYZE_FAILED`** (HTTP **502**). Existing codes (**`DRM_PROTECTED`**, **`LINKCLIP_ERR_*`**, **`FACEBOOK_EXTRACT_FAILED`**, etc.) unchanged.
- **Analyze failure logs** include `classification`, `code`, `urlHost`, `platform`, `statusCode`, `cooldownKey`, `hasCookiesConfigured`, `tempCookieUsed` (no cookie values). Regression: `cd backend && npm run diag:ytdlp-classify`.

#### Facebook fallback (HTML / embedded JSON → direct CDN MP4)

- **Trigger only when:** host is Facebook (`facebook.com`, `fb.watch`, etc.) **and** yt-dlp failed **and** stderr contains **`Cannot parse data`** (case-insensitive). All other URLs and failures keep the existing yt-dlp-only behavior.
- **Implementation:** uses a **Desktop Chrome** request profile first (`Accept`/`Sec-Fetch-*`/`Upgrade-Insecure-Requests`/Chrome **125** UA) so Facebook returns standard embedded JSON/CDN hints instead of **WebLite** “unsupported” interstitial HTML often seen with mobile/iPhone-style profiles; **Android Chrome mobile** and **mbasic** requests remain as fallbacks. Parses quoted JSON keys (`playable_url`, `browser_native_*`, `videoDeliveryLegacyFields`, `dash_manifest`, etc.) plus guarded `video*.fbcdn.net` MP4 patterns — **never** calls FDOWN, **never** scrapes third-party download sites.
- **`Link.facebookDirectFallback`:** set when analyze succeeds via this path. The download worker **re-runs** the extractor at job time (signed CDN URLs expire quickly).
- **`sourceUrl` / stored link URL:** remains the **original** Facebook URL shared by the user — not the ephemeral CDN URL.
- **Titles / thumbnails:** server decodes HTML entities in fallback metadata and normalizes thumbnail URLs; the Android client sends **Referer + User-Agent** for `*.fbcdn.net` preview images only (no cookies).
- **Failure:** HTTP **422**, code **`FACEBOOK_EXTRACT_FAILED`** (English message + Flutter Hebrew mapping).
- **Operational note:** when testing yt-dlp or curl with production cookies, copy `global.txt` to a **writable temp file** — do not pass the read-only secrets mount as `--cookies` (yt-dlp may rewrite the jar).
- **Dev diagnostic:** `cd backend && npm run diag:facebook -- "<facebook-url>"` — prints redirect probe (desktop Chrome), **per-step profile + variant**, HTML token counts (`.mp4`, `dash_manifest`, `videoDeliveryLegacyFields`, playable/native keys, WebLite unsupported markers), whether SD/HD were extracted, and **candidate hosts only** — not signed URLs or cookies. The production Docker image copies `backend/scripts` into `/app/scripts`, so the same `npm run diag:facebook` command works inside the API/worker container (`cd /app`).

### Local video uploads (Phase A–B backend)

- **Purpose:** device-uploaded **local source** videos for on-server editing; uploads do **not** create `DownloadJob` rows and do **not** appear in the Home downloads list.
- **Phase B:** **`POST /edits`** may use **`sourceUploadId`** (exactly one of download vs upload source); worker resolves **`UploadedMedia.storageKey`** into the same ffmpeg pipeline as download-based Quick Edit.
- **Prisma:** `UploadedMedia` (`devices/<deviceId>/uploads/<uploadId>/source.<ext>`, optional `thumbnail.jpg`).
- **API:** `POST /uploads/videos` (multipart field **`file`**); `GET /uploads/:id` (metadata); `GET /uploads/:id/file`; `GET /uploads/:id/thumbnail` (404 if no thumbnail). All require device auth + ownership.
- **Limits (env):** `MAX_LOCAL_VIDEO_UPLOAD_MB` (default **175**), `MAX_LOCAL_VIDEO_UPLOAD_DURATION_SECONDS` (default **420**). Validation uses **ffprobe** + allowed containers (mp4/mov/webm family); declared MIME must be allowed or **`application/octet-stream`**.
- **Retention:** filesystem cleanup uses **`UPLOAD_RETENTION_MINUTES`** (default **120**) under `*/uploads/*`; downloads/edits and other storage still follow **`MEDIA_RETENTION_MINUTES`** (default **30**). **`MEDIA_RETENTION_MINUTES` for downloaded `FileAsset` records is unchanged** in application logic.
- **Roadmap (mobile):** **Phase C1 done:** models (**`UploadVideoResponse`**), **`ApiClient.uploadVideo`**, **`CreateEditJobRequest.download/upload`**, edit-detail fields (**`sourceKind`**, **`sourceUploadId`**), upload/edit error l10n. **Phase C2–C4:** `EditVideoScreen` upload source, pickers, home banner flow (see `docs/LOCAL_VIDEO_EDITING_PLAN.md`). Download-based Quick Edit is unchanged.

### Downloads

- Create: `POST /downloads` — optional **`forceNew: true`** skips “reuse completed job for same link/format/quality” cache so redownload after expiry gets a **new** `DownloadJob` (`download.service.ts`).
- Poll: `GET /downloads/:id`, list `GET /downloads`.
- File: `GET /downloads/:id/file` (authenticated stream).
- Responses expose **`sourceUrl`** (from linked URL) where applicable for client redownload flows (`download.service.ts`).
- **DRM failures:** If the download worker hits yt-dlp DRM stderr, the job error field stores **`DRM_PROTECTED`** (machine-readable token); Slack classification **`drm_protected`** / error code **`DRM_PROTECTED`** (host only in Slack body—no full URL, no stderr). BullMQ jobs already use **`attempts: 1`** for downloads.

### Quick Edit

- `POST /edits` — body includes **exactly one** of **`sourceDownloadJobId`** (completed download job, existing Quick Edit) **or** **`sourceUploadId`** (`UploadedMedia` id from Phase A upload API), plus **`operations`**. **Video sources** (download with video `FileAsset` or upload): trim, **`rotate`** with **`degrees`**: **90 / 180 / 270** — **0°** must not appear; invalid values → **`UNSUPPORTED_ROTATION`**; **`format`** with `aspectRatio` + **`mode`**: **`fill`** or **`fit_blur`** — omitted defaults to **`fill`**; legacy **`crop`** still accepted and implies fill; **`speed`** with fixed factors **0.5 / 1.25 / 1.5 / 2** — factor **1** must not appear; **`UNSUPPORTED_SPEED_FACTOR`**). **Audio-only sources** (completed download with audio `FileAsset`, no video): **`trim`** (≥ **1 s** span), **`speed`** with **0.75 / 1 / 1.25 / 1.5 / 2**, **`audioQuality`** **`standard` / `high` / `best`** (libmp3lame **128k / 192k / 320k**); video-only ops rejected → **`EDIT_AUDIO_UNSUPPORTED_OPERATION`**; bad trim → **`EDIT_AUDIO_INVALID_TRIM`**; export failure → **`EDIT_AUDIO_EXPORT_FAILED`**. Same route/queue — worker branches on ffprobe (no video stream + audio present → MP3 pipeline). invalid format **`mode`** → **`UNSUPPORTED_FORMAT_MODE`**; **`captions`** **V1.5 / V2.2 / V2.4 / V3.3**: **`language`**: **`auto`**, **`burnIn`**: **`true`**; **`mode`**: **`auto`** (Whisper transcription in worker after trimmed/sped timeline mux) **or** **`segments`** (client‑supplied cues after **`POST /edits/captions/draft`** review — **requires** non‑empty **`segments`** array of **`{ startSec, endSec, text, words? }`**; invalid segments → **`INVALID_CAPTION_SEGMENTS`**; invalid word rows are ignored/fallbacked, not fatal); optional **`wordHighlight`**: **`none`** / **`color`** / **`box`** (default **`none`**, invalid → **`UNSUPPORTED_CAPTIONS_WORD_HIGHLIGHT`**); **V3.4B** optional **`normalTextColor`**, **`activeTextColor`**, **`boxColor`** (white/yellow/purple/mint/**black** — invalid → **`UNSUPPORTED_CAPTIONS_COLOR`**), **`boxShape`** (**`rectangle`** / **`rounded`** / **`pill`**, default **pill**, invalid → **`UNSUPPORTED_CAPTIONS_BOX_SHAPE`** — mobile may omit until **V3.4C**). **V3.5** optional text outline: **`outlineEnabled`** (boolean), **`outlineColor`** (same palette as text colors), **`outlineWidth`** (**`thin`** / **`medium`** / **`thick`**, default **medium**, invalid → **`UNSUPPORTED_CAPTIONS_OUTLINE_WIDTH`**) — applied on **ASS/libass** static path and **canvas** word-highlight plates (same outline for normal + active word in MVP). **`OPENAI_API_KEY`** is required only when a job uses **`captions.mode auto`** **or** the user requests a **draft**; **`style`**: legacy **`default`** / **`clean`** / **`bold`** / **`dark_box`** plus **V3.2** **`clean_pro`**, **`bold_social`**, **`yellow_headline`**, **`dark_bubble`**, **`highlight_box`** (resolved **`default`** → **`clean`**); optional **`fontSize`** (**`extra_small`…`xx_large`**, default **medium**), **`fontFamily`** (**`default`**, **`heebo`**, **`rubik`**, **`assistant`**, **`noto_sans_hebrew`**, default **`default`**), **`position`** / **`color`** (white/yellow/purple/mint, default **bottom** / **white**); optional **`offsetX`** (−240…240) / **`offsetY`** (−180…180), default **0** (invalid → **`UNSUPPORTED_CAPTIONS_POSITION_OFFSET`**, surfaced like position errors); **V3.4B hybrid burn-in:** **`wordHighlight=none`** → existing **ASS/libass** path unchanged; **`wordHighlight=color|box`** → **`@napi-rs/canvas`** PNG plates → one **ProRes 4444 MOV alpha overlay** (`yuva444p10le`) → final encode **two inputs only** (`[1:v]format=rgba` + `overlay=format=auto`) when **`LINKCLIP_CAPTION_HIGHLIGHT_OVERLAY=true`** (default). **V3.4C:** **`pink`** text/box color; optional **`normalTextColor`**, **`activeTextColor`**, **`boxColor`**, **`boxShape`** (mobile sends when highlight on). **`mode=auto`** and **`mode=segments`** both support word highlight **without** requiring a draft (draft is for text/timing edits only). Auto path: single Whisper pass in worker → normalized segments → approximate word timing when **`words[]`** missing. **Kill switch / fallback:** flag **off** or overlay failure → **static ASS only** (`captionsConfigForAssBurn` forces **`wordHighlight=none`** — **no** deprecated ASS inline highlight). ASS applies **preset styling**, per-event **`\pos`** anchors (**`\an2`** bottom / **`\an8`** top), **2-line wrapping** for static captions. **missing API key when `captions.mode auto`** → **`CAPTIONS_TRANSCRIPTION_UNAVAILABLE`** (HTTP **503**); **`CAPTIONS_GENERATION_FAILED`** on Whisper failures in the worker; **`CAPTIONS_DRAFT_UNAVAILABLE`** when draft transcription fails; mute, compress — validated in `edit.schemas.ts`). Codes: **`EDIT_SOURCE_REQUIRED`**, **`EDIT_MULTIPLE_SOURCES`**, **`EDIT_UPLOAD_NOT_FOUND`**, **`EDIT_UPLOAD_NOT_READY`**, **`EDIT_SOURCE_FILE_MISSING`** where applicable.
- `POST /edits/captions/draft` — **Captions Draft V2.4A (+ V3.3 words)**: same XOR **`source*`** fields as **`POST /edits`**, **`operations`** accept **only** **`trim`** + **`speed`** so draft timestamps align with edited output timeline; synchronous handler builds the same preprocessor mux ffmpeg uses before Whisper (**no subtitle burn yet**); returns **`segments`** with stable **`id`**, Whisper **`start/end`**, **`text`**, optional **`words[]`** when model/provider emits word timestamps, plus **`durationSec`**, **`language: auto`**. Errors: **`CAPTIONS_DRAFT_UNAVAILABLE`**. Logs avoid transcript payload (**counts / duration / model / word counts** only).

- `GET /edits/:id/file` — output when `done` (supports range requests).
- `POST /edits/:id/retry` — re-queue failed job.

Download-based Quick Edit behavior (validation, redownload/expiry flows) is **unchanged** when using **`sourceDownloadJobId`**.

**Worker:** `backend/src/workers/worker.ts` runs **both** `createDownloadWorker` and `createEditWorker` in one process.

### Admin & diagnostics

- **`GET /admin/diagnostics`** — structured checks: storage, yt-dlp, ffmpeg, cookies heuristic, YouTube readiness, DB, Redis, queues, recent failures. Details: `backend/docs/ADMIN_DIAGNOSTICS.md`. **Production runtime:** `cd backend && npm run diag:runtime` validates **yt-dlp**, **yt-dlp-ejs** (pip), **node**, **ffmpeg**, and **caption fonts** (when fontconfig is present) before trusting download health. **Audio edit:** `npm run diag:audio-edit` (synthetic MP3, trim/speed/quality exports, ffprobe audio-only). **yt-dlp stderr classification:** `npm run diag:ytdlp-classify`. **YouTube reliability diagnostics:** `diag:youtube-matrix` (baseline), `diag:youtube-pot` (PO), `diag:youtube-proxy` (egress). **Measured (2026, 5-URL sample):** cookies-only **1/5** success; PO-enabled **1/5** success — PO connected but did not improve sample; **keep PO disabled** unless retesting. **PO provider security:** `bgutil-pot` logs may contain token values — do not share `docker logs`. **Proxy spike (disabled by default):** `YTDLP_PROXY_ENABLED=false`, YouTube-only `--proxy` when enabled; no proxy credentials in git; compare direct / PO / proxy / PO+proxy via `YOUTUBE_DIAG_YTDLP_MODE` — see `ADMIN_DIAGNOSTICS.md`.
- **`GET /health`** — public liveness.
- Other admin routes (e.g. invite codes) — see `admin.routes.ts`.

### Storage paths

- Configurable **`STORAGE_DIR`** (default `/app/storage` in production examples).
- **Downloads:** per-device `videos/`, `audio/`, `thumbs/` (see download worker).
- **Uploads (local source):** `devices/<deviceId>/uploads/<uploadId>/source.<ext>` and optional `thumbnail.jpg`.
- **Quick Edit outputs:** `devices/<deviceId>/edits/<editJobId>.mp4` (video) or **`.mp3`** (`audio/mpeg`) for audio-only edits.
- Prisma models tie jobs / uploads to storage keys / filenames; edited outputs stored separately from originals (see `QUICK_EDIT_ARCHITECTURE.md` §5 for intended layout).

### Cleanup & retention

- **`MEDIA_RETENTION_MINUTES`** — default **30** in `docker-compose.prod.yml` cleanup service.
- Cleanup runs every **300s**, deletes files not modified within retention window.

### Rate limits

- **`DEFAULT_DAILY_LIMIT`** — env default (**20** in `.env.production.example`) for **new** devices (`config.ts`).
- **`Device.dailyLimit`** — persisted **per device** in Postgres (`schema.prisma`); normal devices use the default at registration unless changed.
- **Development / QA:** Operators may **manually set a high `dailyLimit`** on a specific device row for testing (redownload loops, etc.). This is an **operational convenience**, not a product rule for end users.
- **Repo hygiene:** Do **not** document real device IDs, operator-specific limits, or production-only overrides in committed docs.

### Errors

- Central **`AppError`** / **`codes`** in `backend/src/types/errors.ts`; Flutter maps known codes via `mobile/lib/core/models/api_error.dart` and **`mobile/lib/core/l10n/api_error_localizations.dart`** (captions-related: **`CAPTIONS_TRANSCRIPTION_UNAVAILABLE`**, **`CAPTIONS_DRAFT_UNAVAILABLE`**, **`INVALID_CAPTION_SEGMENTS`**, **`CAPTIONS_GENERATION_FAILED`**, **`UNSUPPORTED_CAPTIONS_MODE`/`LANGUAGE`/generic fallback**, granular **`UNSUPPORTED_CAPTIONS_STYLE`**, **`UNSUPPORTED_CAPTIONS_POSITION`**, **`UNSUPPORTED_CAPTIONS_POSITION_OFFSET`**, **`UNSUPPORTED_CAPTIONS_FONT_SIZE`**, **`UNSUPPORTED_CAPTIONS_COLOR`**, **`UNSUPPORTED_CAPTIONS_FONT_FAMILY`**).
- **`DRM_PROTECTED`** — DRM-blocked yt-dlp flows (e.g. Spotify); Flutter **`errorDrmProtected`** (EN/HE).
- **Analyze yt-dlp (typed):** **`YOUTUBE_AUTH_REQUIRED`**, **`YOUTUBE_GEO_RESTRICTED`**, **`NO_DOWNLOADABLE_FORMATS`**, **`FACEBOOK_NO_FORMATS_FOUND`** — Flutter title/body pairs in ARB + **`localizedApiErrorDetail`** on analyze **`ErrorView`**.

---

## 5. Mobile Android Summary

**Project:** `mobile/` — Flutter package `private_video_downloader`.

- **Branding (Android):** Launcher display name **`LinkClip`** (`AndroidManifest.xml` `android:label`). Launcher icon from padded source **`assets/app_icon/linkclip_icon_padded.png`** (artwork ~76% of canvas; original `assets/edit-video.png`) via **`flutter_launcher_icons`**: adaptive icon white background (`#FFFFFF`), **18%** foreground inset. Regenerate: `cd mobile && dart run tool/pad_launcher_icon.dart && dart run flutter_launcher_icons`. Shareable APKs: after `flutter build apk`, run `mobile/scripts/copy_linkclip_apk.ps1` to copy `app-*.apk` → **`LinkClip-debug.apk`** / **`LinkClip-release.apk`** under `build/app/outputs/flutter-apk/` (Flutter’s default names are left unchanged).

### Structure (high level)

| Path | Role |
|------|------|
| `lib/features/home/` | Home: compact **Paste link** / **Edit video** row, segmented **Downloads** / **Edits** tabs, compact download cards (primary action + menu / long-press / swipe) |
| `lib/features/analyze/` | Analyze flow, **Video / Audio** tabbed quality selector (`quality_selector.dart`), brain SVG hero (`brain_side_profile.svg` via `flutter_svg`) |
| `lib/features/download_status/` | Progress, success actions (open/share/edit) |
| `lib/features/edit/` | Quick Edit UI (horizontal **scrollable** tool strip: Trim → Speed → Format → Captions → Audio → Quality — **RTL-aware overflow arrows + edge fades** when tabs clip), **Captions V1.5–V3.4I** panel: OFF = inviting CTA card; ON = compact **Captions on** bar + creator **Look** hero (sample preview + swatches) + secondary **Draft**; **MP3** downloads open **`AudioEditScreen`** only after local save guard (**V1.1**: range trim UI, long-press nudge, video-matched progress/success, reliable MP3 share; **V1.2**: save-now progress dialog + snackbar, compact preview, speed/quality combined card, tap-to-edit trim times; **V1.3**: primary preview timeline with **draggable S/E handles**, scrub playhead, play selection; **V1.3.1**: synchronized trim range bar restored in Trim Audio section (shared timeline component, trim mode); **`AudioDownloadScreen`** remains fallback when source invalid; **`CaptionLookEditorScreen`** (Presets / Text / Highlight / Position; **V3.5** Text tab adds outline on/off, color, width; **V3.4G** preview stage + D-pad fine-tune); full styling in look editor only; **`captions`** JSON is explicit **`style` / fontSize / fontFamily / position / color / wordHighlight / `offsetX` / `offsetY`** — preset key not sent), **approximate captions overlay** with static highlighted sample word when word highlight is on; draft segments preserve optional **`words[]`** for **`mode=segments`** burn (no per-word editor); expired-source sheet, trim/speed/format/audio/quality controls |
| `lib/features/onboarding/` | Register device |
| `lib/features/settings/` | Settings |
| `lib/core/` | API client, theme (`linkclip_palette.dart`, `app_theme.dart`), storage (`local_session.dart`), l10n helpers |

### Behavior

- **Session:** Device registration + persisted **device token**; API base URL resolves to **`https://api.linkclip.win`** when **`custom_server_url_enabled`** is off and `--dart-define=API_BASE_URL` is empty (**`LocalSession.bootstrap`** persists that default and **does not** resurrect `server_base_url` from prefs alone — avoids Android backup restoring a dead LAN URL on “clean” installs). When custom server is on, the saved URL is used (`local_session.dart`, `build_flags.dart`). **`LocalSession.serverUrl`** and **`effectiveApiBaseUrl`** both reflect the resolved base (never blank for API calls once bootstrap finished). **Unregistered** users see **Register device** and must tap it (no silent client-side auto-register on cold start); optional Advanced URL override for LAN/staging. Optional prefs for download-create payloads (`LocalSession` prefixes such as `dl_create_` for redownload params).
- **Registration onboarding (`RegisterDeviceScreen`):** Default UI is **helper copy + muted bundled-server line + Register device** — no empty text fields, no device-name field, no editable server field on this screen. Optional **invite code** appears only after **Have an invite code?** / **יש לך קוד הזמנה?**. Registration payload uses a short default device label (**Android** / **iOS** / OS id). Language is available from an **AppBar** icon (`language_picker.dart`) plus **Settings**.
- **Settings language:** Single tappable row (**Language** / **שפה**) with trailing locale name — opens the existing picker.
- **Downloads list:** Recent jobs on home; **Edit** available for completed **video** items (not audio-only — enforced in UI logic).
- **Analyze screen:** Orbital rings backdrop + **vector brain** asset (`assets/illustrations/brain_side_profile.svg`), pulse animation (`pulsing_analyze_brain_svg.dart`).
- **Saved exports:** User-visible folder messaging aligns with **Downloads → PrivateVideoDownloader** (see `media_export_constants.dart` / l10n path helpers); RTL-safe path display.
- **Download / Analyze performance:** Safe stage logs (`[Perf][Download]`, `[Perf][Analyze]`, `[Perf][MobileDownload]`). **TikTok-ready:** AVC/H.264-preferring selector + normalize (production-verified). **Analyze:** Redis short-TTL (60s) full-response cache keyed by `urlHash` plus same-process in-flight dedupe — cache hits skip yt-dlp and Link upsert; daily quota still increments per POST; failures not cached; invalid cache entries are deleted best-effort; every request (including failed in-flight followers) logs its own `analyze_total`. Normalize and file-stream logs are path-free. **`best` unchanged.** See `docs/LINKCLIP_DOWNLOAD_PERFORMANCE.md`.

- **Final file flow (unified readiness):** **Stage A** — backend prepares output. On `done`, auto-finalize downloads into **app cache only** (no MediaStore / public Downloads). Ready means cache-ready for Open/Share. **Save to device** is the only action that publishes to MediaStore via `publishLocalJobMediaToDevice`. Share/Open use the internal cache path (`XFile` / OpenFilex) and never create a public copy. Concurrent ensure calls share one in-flight Future per jobId.
- **Expired server files:** When the user explicitly taps **Save to device**, **Open**, or **Share** on a completed download that has **no** local copy yet, a missing `GET /downloads/:id/file` (e.g. `FILE_NOT_FOUND`, `JOB_NOT_FOUND`, or binary `DEVICE_FILE_DOWNLOAD` with HTTP **404/410**) opens a **redownload** sheet—not a generic snackbar. **Passive** job polling/list refresh does **not** open this sheet. Quick Edit’s existing retention/expiry sheet copy and behavior stay separate (`quick_edit_source_expired_sheet.dart`); both flows share **`navigateToRedownloadAfterExpiry`** (`expired_download_navigation.dart`).
- **Upload source missing:** If an upload-based edit hits missing-upload/source errors, the app shows a **choose again** dialog (no “download again”).
- **Edited output missing:** If fetching the edited MP4 from the server fails with the same missing-binary pattern and there is no local file yet, the failure screen uses **`EDIT_OUTPUT_UNAVAILABLE`** / localized “no longer on server…” copy (no fake redownload of edit outputs).
- **Foreground hint copy:** Non-alarming “keep the app open until…” lines appear during **analyze** loading, **download** progress / initial job loading / save-to-device streaming, **local video upload** for edit, and **edit processing** (`keep_app_open_hint.dart`). No WorkManager, foreground service, or push notifications were added.

### Recent UI / UX polish (Android)

Recent iteration focused on clarity and layout stability (some areas may still be refined in QA):

- **Home:** Compact **Paste link** / **Edit video** row; **downloads** / **edits** use **aspect-aware project tiles** with **letterbox-aware** thumbnail handling: if a remote thumb is a tall canvas with baked black bars around landscape content, the tile uses the **content** aspect and crops bars for list display (`thumbnail_letterbox.dart`, `LinkClipMediaThumbnail`). List fit is **cover**; no platform-forced portrait. Status/meta beside the tile; primary CTA below.
- **Home — local edit history (`Edits` tab):** Same tile rules using stored `width`/`height` when available; duration badge on thumb; **Open** primary CTA (`home_edits_tab.dart`).
- **Analyze result:** Large-preview hierarchy — ~36% height media stage (`LinkClipMediaPreviewCard`), title max 2 lines, platform/duration chips, cleaner quality rows (no oversized icon circles), sticky-feel primary prepare CTA (`analyze_screen.dart`, `quality_selector.dart`). Analyze/wakelock/download-create behavior unchanged.
- **Download status screen:** Large-preview result layout; after backend `done`, auto local final-file ensure before showing ready; Open/Share/Save reuse local file. ActiveOperation resume unchanged; no MiniCard / PiP / DownloadManager.
- **Design system (UI cleanup):** Shared tokens/components in `mobile/lib/core/theme/linkclip_design_system.dart` — spacing (`xs`–`xxl`), radii (`small`/`medium`/`large`/`card`), `LinkClipSectionCard`, `LinkClipSectionHeader`, `LinkClipChoiceChip`, `LinkClipStickyActionBar`, `LinkClipInlineEmptyState`, `LinkClipMediaPreviewCard`. Applied to edit Format/Speed/Trim, captions empty state, downloads/edits cards, download status, analyze result, working progress. **No** OperationMiniCard / PiP / DownloadManager.
- **Analyze:** Hero uses a **lateral human-brain style SVG** (public-domain diagram lineage, LinkClip palette) plus existing **orbital rings** behind it; gentle pulse/glow (`analyze_processing_animation.dart`, `pulsing_analyze_brain_svg.dart`).
- **Quick Edit processing:** Calm progress + optional framed hero animation; rings stay in the muted blue/slate family (`edit_processing_animation.dart`). **Foreground operation wake lock:** screen stays awake during active link analyze, server download polling, local save-to-device, caption draft generation (visible wait), and edit/export (`wakelock_plus` via refcounted `operation_wakelock.dart`); released on success/failure/cancel/back/dispose — not held on idle or post-success result screens. **Active operation store (V1):** `ActiveOperationStore` + `OperationController` persist in-flight source download and edit/export jobs by backend `jobId` in SharedPreferences (`active_operation_v1`); background polling resumes on screen dispose, app `resumed`, and cold start; pending download create persisted as `starting` (no jobId) until POST returns; foreground screens sync UI from controller cache + forced poll on resume (no manual refresh); debug traces via `operation_debug.dart`. **Export progress UX:** staged localized headlines + capped progress bar (`edit_progress_display.dart` — backend `stage`/`progressPercent` when present, time-based estimate otherwise; caption-aware burn messages).
- **Edit screen:** Large-preview composer shell — preview stage ~40% of body height (clamped), tool strip under preview, one active panel card, sticky Exit/Create bar (`edit_video_screen.dart`). Preview fills the allocated stage with **contain letterboxing** (no longer locked to a short 16:9 outer box) so portrait clips read larger (`edit_video_preview.dart`). Format/Speed/Trim/Captions/Audio/Quality panels share the same card shell + `LinkClipSectionHeader` / chips. Captions no-draft state emphasizes create-draft CTA (hides redundant draft card). Progress/working screens use clearer hierarchy without changing wake-lock or ActiveOperation behavior. **Unified edit preview foundation** (`edit_preview_state.dart`, `docs/EDIT_PREVIEW_CAPABILITY_MATRIX.md`): passive `EditPreviewState` drives preview **speed**, **mute**, caption overlay, crop guide — export via `buildQuickEditOperations`. **Caption preview consistency**: no-draft explanation + CTA in Captions tab (no sample on video); live draft working-copy; draft editor in draggable sheet; output cards use `resolveMediaOutputPreview` / `MediaOutputPreviewThumbnail`. **Format** panel: video shape, Fill vs Keep-all, and **Rotation**. **Speed** is **constant for the entire output only**. **Captions V1.5 / V3.2:** **Auto captions** (**off** by default); Look Editor sample text on **`CaptionPreviewCard`** only. Draft text/timing editor + presets. No translation/word‑karaoke/export/free color pickers.
- **Trim:** Digit-only **MM:SS** input (silent clamp), sheet opens **empty** with raw digits while editing + subtle **preview** line, **Apply** skips change if no digits (**Cancel** restores), **S/E** thumbs (large touch targets) (`trim_editor.dart`, `trim_mm_ss_input.dart`, `trim_labeled_thumb_shape.dart`).
- **Aspect ratio & fit:** **`format_editor.dart`** — **video shape** presets plus **Fit mode**: **Fill** (scale-to-cover + center crop / previous behavior), **Fit** (scale-to-fit + blurred background via split/overlay inside the existing pipeline). Crop preview overlay applies only when **Fill** + non-original shape (`crop_preview_overlay.dart`).
- **Save path copy:** Folder path strings use **RTL-safe** presentation for **Downloads → PrivateVideoDownloader** / **הורדות > PrivateVideoDownloader** (`media_export_display_path.dart`, l10n).
- **Settings:** Cleaner consumer layout — **Language** row (**Language** / **שפה** + trailing locale), theme choice in bordered panel, bundled server/device info in quiet cards, **Advanced** collapsed by default (**ExpansionTile**) with contained URL field; **factory reset** as subdued **Outlined** button (`settings_screen.dart`).

### Localization

- ARB files under `mobile/lib/l10n/`; run **`flutter gen-l10n`** after string changes.

### Release build

```bash
cd mobile
flutter pub get
flutter gen-l10n
flutter analyze
flutter build apk --release --dart-define=API_BASE_URL=https://api.linkclip.win
```

APK output:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Quick Edit Summary

### Backend

- **Phase 1 implemented:** Prisma **`EditJob`** model, `edit` module, ffmpeg pipeline (`edit.ffmpeg.ts`), BullMQ **edit queue**, worker consumer (`edit.worker.ts`).
- **Operations:** trim (time range), optional **`rotate`** (**90 / 180 / 270** clockwise, pixel **transpose**/**flip** — not metadata-only; **0°** = omit op), **`format`** (preset aspect ratios; **`fill`** = crop-to-cover; **`fit_blur`** = fit-in-frame + blurred background; legacy **`crop`** = fill), optional **`captions` V1.5 (+ V3.2 Style Pack + V2.2 offsets + V2.4A draft/edited cues)** (**`mode auto`**: Whisper on the timeline mux intermediate + burn; **`mode segments`**: client cues only — Whisper skipped; highlight overlay or ASS per **`wordHighlight`**; **normalized** overlaps/blank cues; export **without overlays** when no subtitle events remain (**no fatal**)), auto transcription paths require **`OPENAI_API_KEY`** + **`OPENAI_TRANSCRIPTION_MODEL`** default **`whisper-1`**; **`POST /edits/captions/draft`** duplicates **trim+speed timeline** preprocessor for **editable** Whisper JSON **without** embedding in final MP4 (**synchronous**, may run long — **no** artificial max duration gate in **V2.4A**). **fontsize** presets **extra_small→16 … xx_large→44**; ASS **`Fontname`** from **`fontFamily`** (**Noto Sans** default; **Heebo/Rubik/Assistant** via Docker **`fontconfig`** + bundled TTFs — `npm run diag:caption-fonts`); **≤2 ASS lines/event** via manual wrap + **time-chunking** overflow within each Whisper segment’s **start/end** (adaptive line width before splitting; **~0.85s** minimum target per sub-event when split; **no** artificial timestamp shifts); transcript **sanitization** removes bogus line-break tokens / stray backslashes before per-line ASS prep (strip `{…}` / stray `{`/`}` in text — **no** `\,` / `\\{` on ordinary punctuation), then a **single** literal `\N` join — avoids visible `\\N` / slash artifacts; **`WrapStyle` 2**; larger vertical **MarginV**; **two-pass** worker for **`mode auto`** (timeline MP4 → **Whisper** → ASS → burn + final mute/compress). **Logs:** Whisper success/failure log **counts / durations / ids / models** — **never** cue text payloads. **Dev:** `npm run diag:ass-captions` (no user text in output); **`npm run diag:caption-highlight`** (auto/segments overlay, alpha-video composite, plate visibility, kill-switch — no caption text in output); optional `LINKCLIP_ASS_DEBUG=true` logs structural ASS flags only. **speed** (**0.5× / 1.25× / 1.5× / 2×**; **1×** omits op), mute, compress (tiered encoding — see schemas/service). FFmpeg conceptual order: trim → **rotate** → spatial **format**, **`setpts`/`atempo`** on A/V (**before Whisper / draft preprocessing**); **mute** affects **final mux audio only**, not transcription source timeline when captions are requested.

### Job lifecycle

1. Client `POST /edits` with **`sourceDownloadJobId`** *or* **`sourceUploadId`** + **`operations`** (exactly one source).
2. Job queued → worker resolves source (download **FileAsset** vs **`UploadedMedia.storageKey`**) → same ffmpeg pipeline → output under `devices/<deviceId>/edits/<editJobId>.mp4`.
3. Client polls `GET /edits/:id` until `done` / `failed`.
4. Client downloads via `GET /edits/:id/file`; open/share/save similar to downloads.

### Flutter

- **`EditVideoScreen`** — **scrollable** tool strip (**overflow arrows + soft edge fades**, RTL-aware) + single visible panel: **Trim**, **Speed**, **Format** (shape + Fill/Fit-blur + **rotation** — not a separate tab), **Captions** (**Captions UX V3 / V3.1 / V3.2 Style Pack**: three cards — **Add captions** → **Caption text** (compact **Draft ready** summary + **Edit captions** opens **`CaptionDraftEditorScreen`**) → **Look** (preset name + summary + **Customize look** → **`CaptionLookEditorScreen`**); **`EditCaptionsPreviewOverlay`** (selected style + draft segment text on Captions tab; passive `IgnorePointer` overlay) reflects font/size/color/style/outline/highlight via **google_fonts**; **Auto captions** + **V2.4A/B draft**: **Generate draft** / **Regenerate draft** (confirmation) on **`trim`**/**`speed`** timeline via **`POST /edits/captions/draft`**, **segment text + timing edits** via reused keyboard-aware bottom sheet in the full-screen editor; Save/Cancel/Clear; empty text allowed locally; **no** waveform/timeline drag/**translation**/karaoke yet), timing/source invalidation helpers + built-in presets incl. **Creator Highlight** / **News Headline**; default control values match **Minimal** preset), **Audio** (mute), **Quality** (compress preset); compose → **`POST /edits`** (**`captions.mode auto`** without draft vs **`segments`** when draft loaded — burns edited **text + timing** without OpenAI) → poll → download.
- **Preview:** `video_player` — local file if present, else network URL to authenticated download file endpoint; **0°/180°** in-editor preview uses **BoxFit.contain** + black letterbox; crop overlay / preview widgets.
- **Trim:** Manual time parsing (`trim_time_parse.dart`), bottom-sheet friendly controls.
- **Export:** Processing animation (`edit_processing_animation.dart`), done/error states, **retry** via API where applicable.

**Architecture doc:** `backend/docs/QUICK_EDIT_ARCHITECTURE.md` remains the **deep** design reference; its header “implementation: none yet” is **stale** relative to current code.

---

## 7. Expired Server Source / Re-download Flow

**Problem:** Cleanup deletes **server-side** media after **`MEDIA_RETENTION_MINUTES`** (~30 min in prod Compose). The phone may still show an old download while the **server file is gone** — Quick Edit **requires** server-side source.

**UX (implemented):**

- User taps Edit on an old item → **expired source** flow (`quick_edit_source_expired_sheet.dart`) → **Download now** triggers a **new** download.
- Client persists prior download-create parameters under prefs (`dl_create_<jobId>` pattern in `local_session.dart`) and uses API **`sourceUrl`** when available.

**`forceNew`:** `POST /downloads` with `{ "forceNew": true }` bypasses completed-job deduplication so the worker fetches fresh media instead of returning a stale completed job (`download.service.ts`).

**Heuristic vs API:** Expiry may still be inferred client-side from age in some paths; improving **`canEdit` / `editableUntil`** from the backend is a listed future improvement (§13).

---

## 8. Cookies / yt-dlp / YouTube Runtime

- **`COOKIES_FILE`:** Points to Netscape-format cookies (e.g. `/app/secrets/cookies/global.txt`); diagnostics validate existence, non-empty, heuristic Netscape shape (`ADMIN_DIAGNOSTICS.md`).
- **Writable copy:** yt-dlp invocations use a **temp copy** so the mounted secret stays read-only (`linkclip-cookies-*.txt` pattern in `ytdlp.ts`).
- **Install:** Docker image installs **`yt-dlp`** and **`yt-dlp-ejs`** explicitly via pip (build fails if either is missing — `yt-dlp --version` + `pip show` in image build). **Caption fonts (V3.2):** **`fontconfig`**, **`fonts-noto-core`/`extra`**, OFL variable **Heebo/Rubik/Assistant** TTFs + **`fc-cache`** for ASS burn-in. **Runtime check:** `cd backend && npm run diag:runtime` (yt-dlp, yt-dlp-ejs, node, ffmpeg; caption fonts when fontconfig is present).
- **Node as JS runtime:** Image ensures `node` on PATH; yt-dlp gets **`--no-js-runtimes --js-runtimes node`** (`YTDLP_JS_RUNTIME_ARGS`) for YouTube **n/challenge** scripts.
- **Diagnostics:** `youtubeReady` combines yt-dlp version, Node, `yt-dlp-ejs` import, and JS args match (`diagnostics.service.ts`).

**Threads:** Hostnames `threads.com` / `threads.net` rejected in **`analyze.service.ts`** with a dedicated error code → Flutter shows `errorThreadsUnsupported` (`urlSafety.ts`, ARB strings).

---

## 9. Storage / Cleanup / Retention

| Item | Detail |
|------|--------|
| Volume | `downloads_data` → `/app/storage` in api/worker/cleanup |
| Retention env | `MEDIA_RETENTION_MINUTES` (e.g. **30** in `docker-compose.prod.yml`) |
| Cleanup | Alpine container; `find … -mmin +$RET -delete` every 5 minutes |
| Edited outputs | Separate keys/paths from originals; subject to same retention unless copied off-server |
| Android visibility | Saved exports documented under **Downloads / PrivateVideoDownloader** (see mobile `media_export_constants` / l10n) |

**Render:** Ephemeral/multi-service disk pitfalls — `docs/render-deploy.md`.

---

## 10. Admin / Operations

### Diagnostics endpoint

```bash
curl -sS "https://api.linkclip.win/admin/diagnostics" \
  -H "Authorization: Bearer <ADMIN_TOKEN>"
```

Plain text:

```bash
curl -sS "https://api.linkclip.win/admin/diagnostics?format=text" \
  -H "Authorization: Bearer <ADMIN_TOKEN>"
```

**Never commit** real `ADMIN_TOKEN` values.

### Informal production aliases

Handoffs sometimes define **`linkclip-diag`**, **`linkclip-errors`**, **`linkclip-logs`**, **`linkclip-ps`**, **`linkclip-health`**, **`linkclip-disk`**, **`linkclip-restart`**, **`linkclip-deploy`** on the server — **not shipped in this repo**. Treat them as optional operator shortcuts wrapping `docker compose`, `curl`, and `journalctl`-style commands.

### Deploy reference

- **`backend/DEPLOY_HETZNER.md`** — Compose up, Caddyfile, cookies dir, health `curl`, APK `--dart-define`.

---

## 11. iOS Notes

- **Current shipped client:** Android APK; **`ios/`** may exist from `flutter create` but iOS is **not** the MVP focus.
- **Requirements for real iOS builds:** macOS, Xcode, CocoaPods, Apple Developer Program; **TestFlight** as typical first distribution channel.
- **Policy risk:** App Store often scrutinizes **downloader** / media-ripper positioning — legal/product review recommended before public listing.
- **Platform differences:** Saving to Photos vs Downloads, Share Sheet, background restrictions — needs dedicated design.
- **Share Extension:** Mentioned in `README.md` / `mobile/README.md` as **future** Phase for receiving URLs like Android `SEND`.

No `linkclip_ios_build_instructions.md` file exists **in this repository** (draft referenced it externally).

---

## 12. Current Known Limitations

| Limitation | Notes |
|------------|--------|
| **Local-only video edit** | Home **Edit video** opens the device picker → **`launchLocalVideoEdit`** → upload/edit pipeline (**Phase A/B**, limits **175MB / 7min**); **Edits** tab shows local edit history. Older “coming soon” Home banner copy is **not** current. |
| **Server retention** | Edits require server source file; expired → redownload (`forceNew`). |
| **Threads** | Explicitly unsupported at analyze (`hostnameIsThreads`). |
| **iOS** | Not built/shipped as MVP. |
| **Staged docs drift** | Root `README.md` Quick Edit section and `QUICK_EDIT_ARCHITECTURE.md` header/status are **out of sync** with shipped Phase 1 (see **§13 — Documentation sync**). Until fixed, prefer **this file + source** over those headers. |
| **Multi-node disk** | Without shared object storage, API/worker **must** share filesystem (Compose on one node works; naive Render split does not). |

---

## 13. Recommended Next Steps

### Documentation sync (do soon)

1. **Root `README.md`** — Replace the “Quick Edit not implemented” paragraph with a short **implemented** summary + pointer to `backend/docs/QUICK_EDIT_ARCHITECTURE.md` and this file.
2. **`backend/docs/QUICK_EDIT_ARCHITECTURE.md`** — Update the **status/header** (e.g. §1 “implementation: none yet”) to state that **Phase 1 is implemented** in code; keep the doc as deep design reference.
3. **`docs/LINKCLIP_PROJECT_SUMMARY.md`** — Remains the **living handoff overview**; bump **Last updated** when behavior or architecture changes.

Until (1) and (2) are done, **this summary + source code** supersede conflicting statements elsewhere.

### Product / engineering

1. **Android QA pass** — analyze → download → open/share/save → Quick Edit (trim/**speed**/format fill & fit-blur/**captions**/mute/compress/combo) → expired → redownload → edit.
2. **Server-driven edit eligibility** — Expose `editableUntil` / `canEdit` from backend instead of pure heuristics.
3. **Policy & product** — Decide scope for **local upload/edit** (heavy product + infra implications).
4. **iOS** — If pursued: Mac CI, signing, TestFlight checklist, Share Extension design.
5. **Monitoring** — Optional: aggregate `recentFailures` from diagnostics or structured logging dashboards.

---

## 14. Important Rules / Development Discipline

- **Do not refactor** the download pipeline or device auth **without strong reason** — high regression cost on device-tested MVP.
- **Do not casually change** yt-dlp invocation, cookies handling, or **Threads** safety checks — breakage shows up only in production extractor drift.
- **Heavy lifting stays server-side:** ffmpeg/yt-dlp in backend; **no client-side ffmpeg** in Flutter for MVP.
- **Test new APIs with `curl`** (or HTTP client) **before** wiring Flutter — isolates auth and schema issues.
- After Flutter string/feature work: **`flutter gen-l10n`**, **`flutter analyze`**, **`flutter build apk`** as appropriate.
- After backend TypeScript changes: **`npm run build`** (and migrations discipline via Prisma).

---

## Appendix: Key file paths

```text
backend/docker-compose.prod.yml     # Production stack (Caddy, api, worker, cleanup, PG, Redis)
backend/DEPLOY_HETZNER.md           # Production URL, deploy steps
backend/docs/ADMIN_DIAGNOSTICS.md   # Diagnostics contract
backend/docs/QUICK_EDIT_ARCHITECTURE.md
docs/DEVELOPMENT_WORKFLOW.md      # Definition of Done + when to update summary
.cursor/rules/linkclip-docs.mdc   # Cursor: remind agents to update summary
scripts/check-project-summary.sh # Optional pre-commit reminder (not installed by default)
mobile/lib/features/edit/edit_video_screen.dart
mobile/assets/illustrations/brain_side_profile.svg
```

---

*End of LinkClip project summary.*
