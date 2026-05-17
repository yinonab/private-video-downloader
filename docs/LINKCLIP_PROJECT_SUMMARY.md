# LinkClip Project Summary

| Metadata | |
|----------|--|
| **Last updated** | 2026-05-06 |
| **Status** | Android Quick Edit MVP implemented; in QA/polish. |
| **Primary platform** | Android |
| **Backend** | Production Docker Compose deployment (see `backend/docker-compose.prod.yml`, `backend/DEPLOY_HETZNER.md`) |
| **Living document** | **Yes** — update after meaningful project changes (see `docs/DEVELOPMENT_WORKFLOW.md`, `.cursor/rules/linkclip-docs.mdc`). |

Polished technical overview of the **private-video-downloader** / **LinkClip** repository: Flutter Android client, Node/Fastify backend, worker, Postgres, Redis/BullMQ, yt-dlp, ffmpeg, and Docker-based deployment. Use this as a handoff doc for developers or future AI sessions.

**Note:** Treat **`docs/LINKCLIP_PROJECT_SUMMARY.md` as the source of truth** until older docs are synced. Some files (root `README.md` Quick Edit section, header/status in `backend/docs/QUICK_EDIT_ARCHITECTURE.md`, environment-specific notes in `docs/handoff.md`) may lag the codebase; **this summary prioritizes what exists in source today**.

---

## 1. Project Overview

**LinkClip** is an Android-first MVP that lets users **analyze** a shared or pasted video URL, **download** media via a backend worker, then **open**, **share**, or **save** files locally. **Quick Edit** runs **on the server** (ffmpeg): trim, crop/aspect ratio, mute, compress — not on-device ffmpeg.

| Layer | Technology |
|-------|------------|
| Mobile | Flutter (`mobile/`), Android MVP |
| API | Node.js, TypeScript, **Fastify** (`backend/src/`) |
| Jobs | **Redis** + **BullMQ** (download queue + edit queue) |
| Database | **PostgreSQL** via **Prisma** |
| Acquisition | **yt-dlp** (`yt-dlp[default,curl-cffi]`), **ffmpeg** / **ffprobe** |
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
| YouTube / JS challenges | Node + `yt-dlp-ejs`; `--no-js-runtimes --js-runtimes node` (`YTDLP_JS_RUNTIME_ARGS`) |
| Admin diagnostics | `GET /admin/diagnostics` (JSON + optional `?format=text`, optional `?deep=true`) — see `backend/docs/ADMIN_DIAGNOSTICS.md` |
| Media cleanup | Separate **cleanup** container; **two-tier** retention on `/app/storage`: `devices/*/uploads/*` uses **`UPLOAD_RETENTION_MINUTES`** (default **120**); all **other** files use **`MEDIA_RETENTION_MINUTES`** (default **30**) — see `backend/docker-compose.prod.yml` |
| Local video uploads (Phase A) | Backend **`UploadedMedia`** + `POST /uploads/videos`, `GET /uploads/:id`, file/thumbnail streams (`backend/src/modules/uploads/`). **175MB / 7min** limits; **not** listed on Home downloads. **Edit-from-upload** wired in later phases. |
| Quick Edit backend | `POST /edits`, `GET /edits/:id`, `GET /edits/:id/file`, `POST /edits/:id/retry` (`backend/src/modules/edit/`) |
| Quick Edit Android | `EditVideoScreen`, tabs, preview, export flow (`mobile/lib/features/edit/`) |
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
- **Cookies:** Host path `backend/secrets/` mounted read-only at `/app/secrets`; yt-dlp uses a **temporary writable copy** of the cookies file when invoking yt-dlp (see `ytdlp.ts`).

---

## 4. Backend Summary

**Layout:** `backend/src/modules/` — `devices`, `analyze`, `downloads`, `edit`, **`uploads`**, `admin`, etc.

### Auth & devices

- Registration: `POST /devices/register` (invite / auto-register controlled by env — see `.env.production.example`).
- Authenticated routes use **device Bearer token** (`authDevice` middleware); context includes `dailyLimit`.

### Analyze

- `POST /analyze` — URL safety (including **Threads** rejection), platform detection, yt-dlp metadata path.
- Rate limiting: **`ANALYZE_DAILY_LIMIT`** (default `200` in example env).

#### Facebook fallback (HTML / embedded JSON → direct CDN MP4)

- **Trigger only when:** host is Facebook (`facebook.com`, `fb.watch`, etc.) **and** yt-dlp failed **and** stderr contains **`Cannot parse data`** (case-insensitive). All other URLs and failures keep the existing yt-dlp-only behavior.
- **Implementation:** uses a **Desktop Chrome** request profile first (`Accept`/`Sec-Fetch-*`/`Upgrade-Insecure-Requests`/Chrome **125** UA) so Facebook returns standard embedded JSON/CDN hints instead of **WebLite** “unsupported” interstitial HTML often seen with mobile/iPhone-style profiles; **Android Chrome mobile** and **mbasic** requests remain as fallbacks. Parses quoted JSON keys (`playable_url`, `browser_native_*`, `videoDeliveryLegacyFields`, `dash_manifest`, etc.) plus guarded `video*.fbcdn.net` MP4 patterns — **never** calls FDOWN, **never** scrapes third-party download sites.
- **`Link.facebookDirectFallback`:** set when analyze succeeds via this path. The download worker **re-runs** the extractor at job time (signed CDN URLs expire quickly).
- **`sourceUrl` / stored link URL:** remains the **original** Facebook URL shared by the user — not the ephemeral CDN URL.
- **Titles / thumbnails:** server decodes HTML entities in fallback metadata and normalizes thumbnail URLs; the Android client sends **Referer + User-Agent** for `*.fbcdn.net` preview images only (no cookies).
- **Failure:** HTTP **422**, code **`FACEBOOK_EXTRACT_FAILED`** (English message + Flutter Hebrew mapping).
- **Operational note:** when testing yt-dlp or curl with production cookies, copy `global.txt` to a **writable temp file** — do not pass the read-only secrets mount as `--cookies` (yt-dlp may rewrite the jar).
- **Dev diagnostic:** `cd backend && npm run diag:facebook -- "<facebook-url>"` — prints redirect probe (desktop Chrome), **per-step profile + variant**, HTML token counts (`.mp4`, `dash_manifest`, `videoDeliveryLegacyFields`, playable/native keys, WebLite unsupported markers), whether SD/HD were extracted, and **candidate hosts only** — not signed URLs or cookies. The production Docker image copies `backend/scripts` into `/app/scripts`, so the same `npm run diag:facebook` command works inside the API/worker container (`cd /app`).

### Local video uploads (Phase A — backend)

- **Purpose:** device-uploaded **local source** videos for **future** on-server editing; uploads do **not** create `DownloadJob` rows and do **not** appear in the Home downloads list.
- **Prisma:** `UploadedMedia` (`devices/<deviceId>/uploads/<uploadId>/source.<ext>`, optional `thumbnail.jpg`).
- **API:** `POST /uploads/videos` (multipart field **`file`**); `GET /uploads/:id` (metadata); `GET /uploads/:id/file`; `GET /uploads/:id/thumbnail` (404 if no thumbnail). All require device auth + ownership.
- **Limits (env):** `MAX_LOCAL_VIDEO_UPLOAD_MB` (default **175**), `MAX_LOCAL_VIDEO_UPLOAD_DURATION_SECONDS` (default **420**). Validation uses **ffprobe** + allowed containers (mp4/mov/webm family); declared MIME must be allowed or **`application/octet-stream`**.
- **Retention:** filesystem cleanup uses **`UPLOAD_RETENTION_MINUTES`** (default **120**) under `*/uploads/*`; downloads/edits and other storage still follow **`MEDIA_RETENTION_MINUTES`** (default **30**). **`MEDIA_RETENTION_MINUTES` for downloaded `FileAsset` records is unchanged** in application logic.
- **Roadmap:** Flutter picker, `EditVideoScreen`, and `POST /edits` integration — later phases (see `docs/LOCAL_VIDEO_EDITING_PLAN.md`).

### Downloads

- Create: `POST /downloads` — optional **`forceNew: true`** skips “reuse completed job for same link/format/quality” cache so redownload after expiry gets a **new** `DownloadJob` (`download.service.ts`).
- Poll: `GET /downloads/:id`, list `GET /downloads`.
- File: `GET /downloads/:id/file` (authenticated stream).
- Responses expose **`sourceUrl`** (from linked URL) where applicable for client redownload flows (`download.service.ts`).

### Quick Edit

- `POST /edits` — body includes source download job id + **operations** (trim, crop, mute, compress — validated in `edit.schemas.ts`).
- `GET /edits/:id` — status / progress / errors.
- `GET /edits/:id/file` — output when `done` (supports range requests).
- `POST /edits/:id/retry` — re-queue failed job.

**Worker:** `backend/src/workers/worker.ts` runs **both** `createDownloadWorker` and `createEditWorker` in one process.

### Admin & diagnostics

- **`GET /admin/diagnostics`** — structured checks: storage, yt-dlp, ffmpeg, cookies heuristic, YouTube readiness, DB, Redis, queues, recent failures. Details: `backend/docs/ADMIN_DIAGNOSTICS.md`.
- **`GET /health`** — public liveness.
- Other admin routes (e.g. invite codes) — see `admin.routes.ts`.

### Storage paths

- Configurable **`STORAGE_DIR`** (default `/app/storage` in production examples).
- **Downloads:** per-device `videos/`, `audio/`, `thumbs/` (see download worker).
- **Uploads (local source):** `devices/<deviceId>/uploads/<uploadId>/source.<ext>` and optional `thumbnail.jpg`.
- **Quick Edit outputs:** `devices/<deviceId>/edits/<editJobId>.mp4` (unchanged).
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

- Central **`AppError`** / **`codes`** in `backend/src/types/errors.ts`; Flutter maps known codes via `mobile/lib/core/models/api_error.dart` and l10n.

---

## 5. Mobile Android Summary

**Project:** `mobile/` — Flutter package `private_video_downloader`.

### Structure (high level)

| Path | Role |
|------|------|
| `lib/features/home/` | Home, paste banner, download cards |
| `lib/features/analyze/` | Analyze flow, quality selector, brain SVG hero (`brain_side_profile.svg` via `flutter_svg`) |
| `lib/features/download_status/` | Progress, success actions (open/share/edit) |
| `lib/features/edit/` | Quick Edit UI, expired-source sheet, trim/crop/compression/audio tabs |
| `lib/features/onboarding/` | Register device |
| `lib/features/settings/` | Settings |
| `lib/core/` | API client, theme (`linkclip_palette.dart`, `app_theme.dart`), storage (`local_session.dart`), l10n helpers |

### Behavior

- **Session:** Device registration + persisted **device token**; optional prefs for download-create payloads (`LocalSession` prefixes such as `dl_create_` for redownload params).
- **Downloads list:** Recent jobs on home; **Edit** available for completed **video** items (not audio-only — enforced in UI logic).
- **Analyze screen:** Orbital rings backdrop + **vector brain** asset (`assets/illustrations/brain_side_profile.svg`), pulse animation (`pulsing_analyze_brain_svg.dart`).
- **Saved exports:** User-visible folder messaging aligns with **Downloads → PrivateVideoDownloader** (see `media_export_constants.dart` / l10n path helpers); RTL-safe path display.

### Recent UI / UX polish (Android)

Recent iteration focused on clarity and layout stability (some areas may still be refined in QA):

- **Analyze:** Hero uses a **lateral human-brain style SVG** (public-domain diagram lineage, LinkClip palette) plus existing **orbital rings** behind it; gentle pulse/glow (`analyze_processing_animation.dart`, `pulsing_analyze_brain_svg.dart`).
- **Quick Edit processing:** Animation emphasizes **scissors**, **filmstrip** shards, and **orbital rings** (purple/indigo family), aligned with other LinkClip loaders (`edit_processing_animation.dart`).
- **Edit screen:** Four tabs — **Trim**, **Aspect ratio**, **Compression**, **Audio** (`edit_video_screen.dart`).
- **Trim:** Manual start/end time entry uses a **bottom sheet** pattern to reduce keyboard overlap with the main layout (`trim_editor.dart`).
- **Aspect ratio:** Presets on a **fixed grid** so selection does not resize cells (`crop_editor.dart`).
- **Crop preview:** Dimmed overlay outside crop, clear crop rectangle, and **thirds** grid (`crop_preview_overlay.dart`, `crop_editor.dart`).
- **Save path copy:** Folder path strings use **RTL-safe** presentation for **Downloads → PrivateVideoDownloader** / **הורדות > PrivateVideoDownloader** (`media_export_display_path.dart`, l10n).

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
- **Operations:** trim (time range), crop/aspect ratio (center crop MVP), mute, compress (tiered encoding — see schemas/service).

### Job lifecycle

1. Client `POST /edits` with `sourceDownloadJobId` + `operations`.
2. Job queued → worker runs ffmpeg → output written under storage layout for edits.
3. Client polls `GET /edits/:id` until `done` / `failed`.
4. Client downloads via `GET /edits/:id/file`; open/share/save similar to downloads.

### Flutter

- **`EditVideoScreen`** — tabbed UI: **Trim**, **Aspect ratio**, **Compression**, **Audio**.
- **Preview:** `video_player` — local file if present, else network URL to authenticated download file endpoint; crop overlay / preview widgets.
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
- **Install:** Docker image installs **`yt-dlp[default,curl-cffi]`** — brings **`yt-dlp-ejs`** and TLS impersonation extras (`backend/Dockerfile`).
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
| **Local-only video edit** | Home **banner Edit** shows **“Editing a video from your device is coming soon”** (`home_screen.dart`, `editLocalVideoComingSoon`) — no gallery picker → server edit pipeline for arbitrary local files. |
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

1. **Android QA pass** — analyze → download → open/share/save → Quick Edit (trim/crop/mute/compress/combo) → expired → redownload → edit.
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
