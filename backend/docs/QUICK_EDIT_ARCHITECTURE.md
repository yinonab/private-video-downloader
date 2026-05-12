# LinkClip Quick Edit Architecture Plan

**Status:** planning source of truth · **Scope:** post-download Quick Edit only · **Implementation:** none yet (see §19 guardrails)

**Navigate:** **§0** — planning Q&A · **§1** — product goal · **§2–20** — detailed design

### Doc map (by section number)

| § | Topic |
|---|--------|
| **0** | Planning checklist (answers product/architecture questions first) |
| **1** | Product goal |
| **2** | Hard architectural rules |
| **3** | Operation-based edit pipeline |
| **4** | MVP feature scope |
| **5** | Future caption system (conceptual) |
| **6** | Backend architecture |
| **7** | Queue strategy |
| **8** | Data model strategy |
| **9** | Storage strategy |
| **10** | ffmpeg strategy |
| **11** | Mobile architecture |
| **12** | API client |
| **13** | Progress reporting |
| **14** | Security and validation |
| **15** | Risks and mitigations |
| **16** | Phased implementation plan |
| **17** | Likely files to add later |
| **18** | Files to minimally touch later |
| **19** | Cursor implementation guardrails |
| **20** | Documentation improvements & maintenance |

---

## 0. Planning checklist — explicit answers (TL;DR)

This section answers the architecture review questions in one place; deeper rationale lives in **§6–17**, phased rollout in **§16**, integration touchpoints in **§18**, guardrails in **§19**, and doc upkeep in **§20**.

### 1. Where should the Quick Edit module live in the backend?

**`backend/src/modules/edit/`**, mirroring existing modules (`downloads`, `analyze`, `devices`):

- `edit.routes.ts`, `edit.service.ts`, `edit.schemas.ts`, `edit.types.ts`
- Isolated ffmpeg planning/building (e.g. `ffmpegEditBuilder.ts`) — **no** coupling to `services/ytdlp.ts` or download paths beyond “resolve source file from download job id”

Worker execution lives **outside** `download.worker.ts`: e.g. **`backend/src/workers/edit.worker.ts`** with its own entrypoint (`npm run worker:edit` or separate Docker command), or a second consumer registered only for the edit queue — **same Redis**, **different queue name**, **no edits to download consumer logic**.

### 2. What new backend endpoints should exist later?

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/edits` | Create edit job (device auth); body = `sourceDownloadJobId` + validated `operations[]` |
| `GET` | `/edits/:id` | Job status: `status`, `stage`, `progressPercent`, errors, `outputReady`, metadata |
| `GET` | `/edits/:id/file` | Binary stream when status is `done` (same auth model as download file route) |
| `POST` | `/edits/:id/retry` | Re-queue failed job with same or sanitized ops (optional MVP+) |
| `DELETE` | `/edits/:id` | Optional cancel + cleanup artifacts |

**Later (captions):** e.g. `GET /edits/:id/captions/:lang.srt` | `.vtt` | `.json` for non–burn-in assets.

### 3. Edit jobs: separate queue/worker or reuse existing queue infrastructure?

**Reuse:** Redis + BullMQ (same pattern as `DOWNLOAD_QUEUE_NAME` in `plugins/queues.ts`).

**Separate:** new queue constant e.g. **`EDIT_QUEUE_NAME = "edit"`**, new `Queue` decoration or parallel plugin — **additive registration** in `app.ts` only when implementing.

**Critical:** do **not** modify **`backend/src/workers/download.worker.ts`** or merge edit jobs into the download processor. Prefer a **separate worker binary/process** so production can scale/restart edits without touching downloads.

### 4. Minimal data model later — DB change or not?

| Approach | Pros | Cons |
|---------|------|------|
| **No Prisma change (MVP experiment)** | Zero migration | Jobs only in Redis/fs; weak audit, retry, listing |
| **Additive `EditJob` (+ future `CaptionTrack`)** *(recommended when building)* | Fits job lifecycle, retries, admin/diagnostics | Requires migration |

**Recommendation:** plan on **`EditJob`** as soon as Phase 1 backend starts; keep **`DownloadJob` untouched**. Optional **`CaptionTrack`** (or JSON blob on `EditJob` short-term) when captions land.

### 5. Where should edited files be stored?

- **Source (immutable):** `…/devices/<deviceId>/videos/<downloadJobId>.%(ext)s` (existing layout)
- **Outputs:** `…/devices/<deviceId>/edits/<editJobId>.mp4` (and sidecars: `.srt`, `.vtt`, `.json`, `.ass`)
- **Scratch:** job-scoped temp dir under storage `tmp/` or `/tmp/linkclip-edit-<editJobId>/` — **atomic rename** to final path after success

**Never overwrite** the original download artifact.

### 6. ffmpeg strategies (trim, crop/resize, mute, compress, combined, future burn-in)

- **Trim:** stream-copy trim **only** when standalone and keyframe-safe; otherwise **re-encode** for accuracy or when combined with filters (**`-ss` after `-i`** when filtering).
- **Crop / resize:** `crop` + `scale` + optional `pad` for letterboxing; **center-crop MVP**; explicit pixel ladders per aspect (§10).
- **Mute:** `-an` or drop audio stream.
- **Compress:** `libx264` + `aac`, preset + CRF tiers (§10); preserve SAR/DAR where needed.
- **Combined:** prefer **single** `ffmpeg` invocation with **one** filter graph (`-filter_complex`) chaining trim window → crop/scale/pad → optional subtitles → encode once.
- **Future burn-in:** `subtitles=` or **`ass=`** filter for styling; **Hebrew/RTL** prefers **ASS** (explicit direction/font) over naive SRT burn-in; embed Unicode fonts in container or mount known font dir.

### 7. What mobile screens/widgets should be added later?

Under **`mobile/lib/features/edit/`**:

- **`edit_video_screen.dart`** — entry with `downloadJobId`, loads source metadata/thumbnail
- Controls: **trim**, **aspect ratio chips**, **mute**, **compression preset**, **export**
- **`edit_export_progress.dart`** — poll edit job, mirror download status UX patterns **without** refactoring download code
- **`data/edit_api.dart`**, **`models/edit_job.dart`**
- Optional widgets: `edit_trim_control.dart`, `aspect_ratio_selector.dart`, `compression_selector.dart`

### 8. Minimum safe integration with existing `DownloadStatusScreen`

**Preferred:** one **“Edit video”** button when:

- Job **`done`**, asset is **video**, and (if applicable) **local/server file is known** — purely **navigate** to `EditVideoScreen(downloadJobId)` with **no changes** to create/poll/download/share internals.

### 9. How should future captions work architecturally?

End-to-end pipeline (operations added later):

1. **Extract audio** — `ffmpeg` → WAV/FLAC segment(s)
2. **Speech-to-text** — pluggable **`TranscriptionProvider`** (Whisper-class API or self-hosted); output **word/segment timestamps**
3. **Canonical transcript** — internal **JSON timeline** (segments with `startMs`, `endMs`, `text`, optional `confidence`)
4. **Translation** — pluggable **`TranslationProvider`** per target locale (**he**, **en**, others)
5. **Exports** — **SRT**, **WebVTT**, **JSON** sidecars stored next to edit output; versioning per language
6. **Burn-in** — optional operation **`burnSubtitles`** reading ASS/SRT + style preset (RTL, font, outline, safe margins)
7. **RTL Hebrew** — ASS with `\rtl` / Unicode bidi + verified fonts; test on-device preview before shipping burn-in defaults

### 10. Risks and mitigations

(See §15.) Additional items:

- **Long encode / CPU** — queue isolation, concurrency caps, timeouts, user-visible stage text
- **STT/translation cost & privacy** — provider abstraction, retention policy, optional on-prem/open-source path
- **Legal/content** — editing user-owned downloads only; terms unchanged until product asks otherwise
- **Font/licensing for subtitles** — ship approved fonts or system-font fallback documented per platform

### 11. Recommended implementation sequence

Align with **§16 (Phased implementation plan)**:

| Phase | Focus |
|-------|--------|
| **0** | This document only |
| **1** | Backend: routes, validation, edit queue + **edit worker only**, ffmpeg single-pass MVP ops, storage |
| **2** | Mobile: Edit screen + API client + minimal DownloadStatus hook |
| **3** | Polish: progress, errors, retry, presets |
| **4–6** | Captions: assets → translation → burn-in RTL |
| **7** | Advanced creator ops |

---

## 1. Product Goal

LinkClip is currently a downloader-first app.

The new editing system should be a complementary post-download workflow:

```text
Analyze → Download → Done → Edit Video → Export Edited Copy
```

The goal is **not** to build a full CapCut-style editor immediately.

The goal is to build a small but extensible Quick Edit system that starts with simple post-download edits and can later grow into advanced creator tools such as:

- automatic captions
- translated captions
- burned-in subtitles
- text overlays
- music overlays
- templates
- watermarking
- speed/reverse
- basic effects

---

## 2. Hard Architectural Rules

### Existing download system must remain untouched

Do not refactor:

- analyze flow
- download flow
- download worker
- yt-dlp platform logic
- cookies temp-copy behavior
- TikTok-ready normalization
- YouTube runtime / yt-dlp-ejs behavior
- existing storage pipeline unless strictly necessary

### Quick Edit must be a separate system

The edit system must be additive.

Existing flow remains:

```text
Analyze → Download → Done
```

New optional flow:

```text
Analyze → Download → Done → Edit Video → Export Edited Copy
```

### Non-destructive editing

The edit system must never overwrite the original downloaded file.

Original downloaded file remains unchanged.

Edited output is always a new file.

Example original:

```text
/app/storage/devices/<deviceId>/videos/<downloadJobId>.mp4
```

Example edited output:

```text
/app/storage/devices/<deviceId>/edits/<editJobId>.mp4
```

Future caption assets:

```text
/app/storage/devices/<deviceId>/edits/<editJobId>.he.srt
/app/storage/devices/<deviceId>/edits/<editJobId>.en.srt
/app/storage/devices/<deviceId>/edits/<editJobId>.captions.json
```

---

## 3. Core Concept: Operation-Based Edit Pipeline

The edit system should be operation-based.

Each edit job receives a source video and a list of operations.

Example MVP operations:

```json
{
  "sourceDownloadJobId": "download-123",
  "operations": [
    {
      "type": "trim",
      "startSec": 2.5,
      "endSec": 48.0
    },
    {
      "type": "crop",
      "aspectRatio": "9:16",
      "mode": "centerCrop"
    },
    {
      "type": "mute"
    },
    {
      "type": "compress",
      "preset": "social"
    }
  ]
}
```

This allows future operations:

```json
[
  { "type": "autoCaptions", "sourceLanguage": "auto" },
  { "type": "translateCaptions", "targetLanguages": ["he", "en"] },
  { "type": "burnSubtitles", "language": "he", "stylePreset": "reels" },
  { "type": "textOverlay", "text": "..." },
  { "type": "musicOverlay", "assetId": "..." }
]
```

The MVP implements only a small subset, but the architecture must support future operations without rewriting the system.

---

## 4. MVP Feature Scope

### Phase 1 MVP operations

Plan for:

1. Trim start/end
2. Crop/resize
3. Mute audio
4. Compress video
5. Export edited copy
6. Save/share edited output

### Aspect ratios

Supported aspect ratios:

- Original
- 9:16
- 1:1
- 16:9
- 4:5

### Export presets

Suggested export presets:

- Original quality
- Social optimized
- Smaller file
- TikTok/Reels-ready

---

## 5. Future Caption System

Captions are not part of the first MVP implementation, but the architecture must prepare for them.

### Future caption pipeline

```text
Source video
↓
Extract audio
↓
Speech-to-text
↓
Timestamped transcript
↓
Optional translation
↓
Caption asset files
↓
Optional burn-in subtitles
↓
Export edited video
```

### Future caption operations

```json
{
  "type": "autoCaptions",
  "sourceLanguage": "auto",
  "provider": "openai-whisper-or-other"
}
```

```json
{
  "type": "translateCaptions",
  "sourceLanguage": "en",
  "targetLanguages": ["he", "es", "fr"]
}
```

```json
{
  "type": "burnSubtitles",
  "language": "he",
  "stylePreset": "bold-social",
  "position": "bottom",
  "rtl": true
}
```

### Caption design requirements

The future caption system should support:

- Hebrew
- English
- RTL text
- multiple target languages
- SRT export
- VTT export
- JSON caption timeline
- burned-in subtitles
- subtitle style presets

### Important

Do not implement caption generation now unless explicitly requested later.

But do design the edit pipeline so captions can be added as operations later.

---

## 6. Backend Architecture

### New backend module

Add a new isolated module, for example:

```text
backend/src/modules/edit/
```

Possible files:

```text
backend/src/modules/edit/edit.routes.ts
backend/src/modules/edit/edit.service.ts
backend/src/modules/edit/edit.schemas.ts
backend/src/modules/edit/edit.queue.ts
backend/src/modules/edit/edit.types.ts
backend/src/workers/edit.worker.ts
```

Worker stays alongside **`download.worker.ts`**, not inside the module folder (mirrors existing worker layout).

Alternative: if the project structure differs, follow existing module conventions.

### Backend endpoints

Proposed API:

```http
POST /edits
```

Creates a new edit job.

Request:

```json
{
  "sourceDownloadJobId": "download-job-id",
  "operations": [
    { "type": "trim", "startSec": 1.2, "endSec": 25.0 },
    { "type": "crop", "aspectRatio": "9:16", "mode": "centerCrop" },
    { "type": "mute" },
    { "type": "compress", "preset": "social" }
  ]
}
```

Response:

```json
{
  "editJobId": "edit-job-id",
  "status": "queued"
}
```

```http
GET /edits/:id
```

Returns edit job status.

Response:

```json
{
  "id": "edit-job-id",
  "status": "running",
  "stage": "processing",
  "progressPercent": 42,
  "sourceDownloadJobId": "download-job-id",
  "outputReady": false
}
```

```http
GET /edits/:id/file
```

Streams the edited output file when ready.

```http
POST /edits/:id/retry
```

Optional retry route for failed edit jobs.

### Edit job statuses

Suggested statuses:

```text
queued
running
done
failed
cancelled
```

Suggested stages:

```text
queued
validating_source
probing
processing
finalizing
done
failed
```

---

## 7. Queue Strategy

Preferred approach:

Use the existing queue infrastructure if it can be reused safely, but do not modify download worker logic.

Recommended:

- separate queue name: `edit`
- separate worker module
- same Redis infrastructure
- no changes to download queue behavior

Example:

```text
download queue → existing behavior
edit queue     → new edit jobs only
```

If a separate worker process is too much for MVP, it can run in the existing worker container, but the code should remain isolated and not be mixed into download worker logic.

---

## 8. Data Model Strategy

### Preferred MVP

Avoid DB schema changes if possible only if the existing storage/job model can safely represent edit jobs.

However, because edit jobs have a different lifecycle, source relationship, output path, operations, progress, and future caption assets, a minimal additive model is likely cleaner.

### Recommended minimal additive model

```text
EditJob
```

Fields:

```text
id
deviceId
sourceDownloadJobId
status
stage
progressPercent
operationsJson
outputStorageKey
outputFilename
outputMimeType
outputSizeBytes
errorCode
errorMessage
createdAt
updatedAt
completedAt
```

Future optional model:

```text
CaptionTrack
```

Fields:

```text
id
editJobId
language
kind
storageKey
format
createdAt
```

Do not change existing `DownloadJob` fields unless absolutely necessary.

---

## 9. Storage Strategy

Original downloaded files stay under:

```text
/app/storage/devices/<deviceId>/videos/
```

Edited files go under:

```text
/app/storage/devices/<deviceId>/edits/
```

Temporary edit files go under:

```text
/app/storage/devices/<deviceId>/tmp/
```

or process-level temp:

```text
/tmp/linkclip-edit-<editJobId>/
```

Rules:

- never overwrite original source video
- write to temp file first
- move/rename to final output only after ffmpeg succeeds
- cleanup temp files on success/failure
- edited files should be covered by existing retention cleanup unless a separate retention policy is added later

---

## 10. ffmpeg Strategy

### Trim

Fast trim option:

```text
ffmpeg -ss <start> -to <end> -i input.mp4 -c copy output.mp4
```

Accurate trim option:

```text
ffmpeg -i input.mp4 -ss <start> -to <end> -c:v libx264 -c:a aac output.mp4
```

Recommendation:

- use accurate trim when combined with crop/compress
- use copy trim only for simple fast trim if safe

### Crop / Resize

Use ffmpeg crop/scale/pad filters.

Suggested output sizes:

```text
9:16  → 1080x1920
1:1   → 1080x1080
16:9  → 1920x1080
4:5   → 1080x1350
```

Need to decide:

- center crop
- fit with blurred background
- fit with black padding

MVP should start with center crop or fit/pad.

### Mute

```text
-an
```

### Compress

Use H.264 + AAC:

```text
-c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k
```

Compression presets:

```text
high_quality: crf 20
social:       crf 23
small:        crf 28
```

### Combined operations

Prefer building **one** ffmpeg command where possible instead of multiple re-encodes.

**Filter graph order (conceptual):** decode → **[trim window]** → crop/scale/pad → optional subtitles/ASS → encode audio/video once. When **both** accurate trim and filters are required, prefer **`-ss` / `-to` or `trim` filter after `-i`** per ffmpeg semantics (avoid `-c copy` with filter graphs).

Example:

```text
trim + crop + compress + mute
```

should ideally produce one ffmpeg run.

### Future subtitles burn-in

Future command may use:

```text
-vf subtitles=...
```

or ASS subtitle rendering for styling.

Need to consider Hebrew/RTL support carefully.

---

## 11. Mobile Architecture

### Minimal integration with existing download UI

Only touch existing `DownloadStatusScreen` minimally:

- if download status is done
- if file is video
- show button: `Edit video`

No other changes to download flow.

### New screen

```text
EditVideoScreen
```

Entry:

```text
EditVideoScreen(downloadJobId)
```

Responsibilities:

- load source download info
- show preview/thumbnail if available
- choose operations
- submit edit job
- show export progress
- show done state
- save/share edited file

### MVP UI controls

Sections:

```text
Trim
Aspect Ratio
Audio
Compression
Export
```

Controls:

- trim start/end selectors
- aspect ratio chips
- mute toggle
- compression preset selector
- export button

### Export progress

Show:

```text
queued
processing
progress percent if available
done
failed + retry
```

### Save/share

Reuse existing file open/share behavior if possible, but do not refactor existing download sharing.

---

## 12. API Client

Add new mobile API methods:

```text
createEditJob(...)
getEditJob(...)
downloadEditFile(...)
retryEditJob(...)
```

Keep separate from existing download API methods.

---

## 13. Progress Reporting

MVP can start with coarse progress:

```text
queued → processing → done
```

If ffmpeg progress is easy to parse, support `progressPercent` later or immediately.

Suggested progress handling:

- parse ffmpeg progress if using `-progress pipe:1`
- otherwise use stage-based progress approximation

---

## 14. Security and Validation

Validate:

- sourceDownloadJobId belongs to same device/user context
- source job exists
- source job is done
- source file exists
- source file is video
- trim start/end are valid
- max duration and max file size limits
- allowed operations only
- allowed aspect ratios only
- allowed compression presets only

Do not allow arbitrary ffmpeg arguments from the client.

All operations must be mapped from safe enum values to server-controlled ffmpeg args.

---

## 15. Risks and Mitigations

### Risk: breaking existing downloads

Mitigation:

- separate module
- separate routes
- separate queue
- minimal button added to existing UI
- no download worker refactor

### Risk: long ffmpeg jobs

Mitigation:

- queue jobs
- timeouts
- progress
- file size limits
- concurrency limits

### Risk: storage growth

Mitigation:

- edited output in same cleanup retention
- temp cleanup
- diagnostics already checks storage

### Risk: invalid edit options

Mitigation:

- strict schema validation
- safe enum-based operations

### Risk: Hebrew/RTL captions later

Mitigation:

- plan CaptionTrack and subtitle style pipeline early
- do not implement burn-in captions until tested carefully

### Risk: future CapCut-like features become hard

Mitigation:

- operation-based pipeline
- job-based processing
- separate assets
- non-destructive editing

---

## 16. Phased Implementation Plan

### Phase 0 — Planning only

Deliver this architecture document.

No code changes.

### Phase 1 — Backend edit job MVP

Implement:

- edit routes
- edit service
- edit queue/worker
- source file validation
- operations schema
- ffmpeg command generation
- output file storage
- GET status
- GET file

Operations:

- trim
- crop/resize
- mute
- compress

### Phase 2 — Mobile Edit screen MVP

Implement:

- Edit Video button on done download
- EditVideoScreen
- basic controls
- create edit job
- progress polling
- done state
- save/share edited output

### Phase 3 — Polish

Add:

- preview thumbnail
- better progress
- better error messages
- retry
- export presets
- maybe simple text overlay

### Phase 4 — Captions foundation

Add:

- CaptionTrack model if needed
- audio extraction
- STT provider abstraction
- caption JSON/SRT generation
- captions preview

### Phase 5 — Captions translation

Add:

- translation provider abstraction
- language selection
- Hebrew/English first
- additional languages later

### Phase 6 — Burned-in subtitles

Add:

- subtitle style presets
- RTL support
- safe ffmpeg subtitle rendering
- burn-in export

### Phase 7 — Advanced creator tools

Possible future operations:

- text overlays
- music overlay
- speed control
- reverse
- watermark
- templates
- transitions
- background blur/fill

---

## 17. Likely Files to Add Later

### Backend

```text
backend/src/modules/edit/edit.routes.ts
backend/src/modules/edit/edit.service.ts
backend/src/modules/edit/edit.schemas.ts
backend/src/modules/edit/edit.queue.ts
backend/src/modules/edit/edit.types.ts
backend/src/modules/edit/ffmpegEditBuilder.ts
backend/src/workers/edit.worker.ts
```

### Mobile

```text
mobile/lib/features/edit/edit_video_screen.dart
mobile/lib/features/edit/widgets/edit_trim_control.dart
mobile/lib/features/edit/widgets/aspect_ratio_selector.dart
mobile/lib/features/edit/widgets/compression_selector.dart
mobile/lib/features/edit/widgets/edit_export_progress.dart
mobile/lib/features/edit/data/edit_api.dart
mobile/lib/features/edit/models/edit_job.dart
```

### Future captions

```text
backend/src/modules/edit/captions/caption.service.ts
backend/src/modules/edit/captions/transcription.provider.ts
backend/src/modules/edit/captions/translation.provider.ts
backend/src/modules/edit/captions/subtitleRenderer.ts
mobile/lib/features/edit/captions/caption_language_selector.dart
mobile/lib/features/edit/captions/caption_style_selector.dart
```

---

## 18. Files to Minimally Touch Later

These should be touched minimally and only when implementing actual phases:

```text
mobile/lib/features/download_status/download_status_screen.dart
```

Only to add an `Edit video` button when a completed video file exists.

**Backend wiring (additive lines only when registering routes/queues):**

```text
backend/src/app.ts                      # register edit routes plugin (one register call)
backend/src/plugins/queues.ts          # optional: second Queue for EDIT_QUEUE_NAME (do not alter download queue setup semantics)
backend/package.json                   # optional: "worker:edit" script
backend/docker-compose.prod.yml        # optional: second worker service or command override
```

Do not modify:

```text
backend/src/workers/download.worker.ts
backend/src/services/ytdlp.ts
backend/src/services/availableQualities.ts
backend/src/modules/analyze/*
```

unless absolutely necessary and explicitly justified.

---

## 19. Cursor Implementation Guardrails

When implementing later phases, Cursor must follow these rules:

1. Implement one phase at a time.
2. Do not refactor the download system.
3. Do not overwrite original videos.
4. Do not accept raw ffmpeg args from client.
5. Keep edit module isolated.
6. Run backend lint/build after backend changes.
7. Run Flutter analyze after mobile changes.
8. Summarize touched files and confirm existing download behavior was not changed.

---

## 20. Documentation improvements & maintenance

- Keep **`backend/docs/QUICK_EDIT_ARCHITECTURE.md`** as the **single source of truth** for Quick Edit until an implementation README exists.
- When phases ship, add a short **`CHANGELOG`** snippet per phase (what endpoints/jobs exist).
- Root **`README.md`** includes a short **Quick Edit (future)** subsection linking here; update that blurb if the planned flow or MVP scope changes.
- **§0 / §1** should stay aligned if product scope shifts (e.g. new MVP operation types).
- Renumber sections only when doing a deliberate doc refactor to avoid broken cross-references.
