# LinkClip Quick Edit Architecture Plan

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
backend/src/modules/edit/edit.worker.ts
backend/src/modules/edit/edit.queue.ts
backend/src/modules/edit/edit.types.ts
```

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

Prefer building one ffmpeg command where possible instead of multiple re-encodes.

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
backend/src/modules/edit/edit.worker.ts
backend/src/modules/edit/edit.types.ts
backend/src/modules/edit/ffmpegEditBuilder.ts
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

Potential backend route registration file may need one line to register edit routes, depending on current architecture.

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
