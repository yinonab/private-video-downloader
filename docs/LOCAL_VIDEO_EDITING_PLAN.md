# Local video editing — phased plan

Concise roadmap for **device-local video** as an edit source (server-side ffmpeg only; no on-device ffmpeg).

## Phase A (backend) — implemented & production verified

- **Model:** `UploadedMedia` (Prisma); **not** a `DownloadJob`.
- **Upload:** `POST /uploads/videos` — multipart **`file`**, streaming validate → `devices/<deviceId>/uploads/<uploadId>/source.<ext>`; optional **`thumbnail.jpg`** via server ffmpeg.
- **Read:** `GET /uploads/:id`, `/file`, `/thumbnail`.
- **Limits:** **175MB**, **420s**; retention **120min** under `*/uploads/*` (`UPLOAD_RETENTION_MINUTES`).

## Phase B (backend) — implemented in repo

- **`POST /edits`** accepts **either** **`sourceDownloadJobId`** (existing Quick Edit) **or** **`sourceUploadId`** (`UploadedMedia.id`), **not both**.
- **`EditJob`** nullable **`sourceDownloadJobId`**, optional FK **`sourceUploadId`** → `UploadedMedia`.
- **Worker** `resolveEditSource()` picks download video **`FileAsset`** (unchanged) or resolves **`UploadedMedia.storageKey`**; **same** ffmpeg args/build/output path (`devices/<deviceId>/edits/<editJobId>.mp4`).
- **`GET /edits/:id`** may include **`sourceKind`**, **`sourceUploadId`** (additive); existing **`sourceDownloadJobId`** unchanged for download-sourced jobs.

## Phase C (Flutter / UX) — split delivery

### Phase C1 — mobile API & models (implemented in repo)

- **`UploadVideoResponse`** (`mobile/lib/core/models/upload_models.dart`) + **`ApiClient.uploadVideo`** (`MultipartFile.fromFile`, streamed upload).
- **`CreateEditJobRequest.download` / `.upload`** — **`toJson`** emits exactly one source key.
- **`EditJobDetailResponse`** parses optional **`sourceKind`**, **`sourceUploadId`**.
- Limits constants **`LocalVideoUploadLimits`** (`mobile/lib/core/config/local_video_upload_constants.dart`) — picker pre-checks (**C3**) + alignment with backend caps.
- L10n + **`localizedApiErrorMessage`** for **`UPLOAD_*`** and edit-source codes; retention-related codes share **`errorUploadSourceUnavailable`**.
- **`http_parser`** added as a direct dependency (multipart **`MediaType`**); **not** a picker dependency.

### Phase C2 — editor source abstraction (implemented in repo)

- **`EditVideoSourceRef`** + **`EditVideoScreen`** accept download vs upload sources; **`EditVideoPreview`** uses **`EditVideoPreviewSource`** (local path → **`VideoPlayerController.file`**, else **`/downloads/:id/file`** or **`/uploads/:id/file`** with Bearer).
- **`CreateEditJobRequest.download` / `.upload`** chosen from source kind; upload missing-source API errors surface **`errorUploadSourceUnavailable`** without the download redownload sheet.

### Phase C3 — Home UI + pickers + upload (implemented in repo)

- **Dependencies:** **`image_picker`** (gallery / device media), **`file_picker`** (`FileType.video`, **`withData: false`**, stream fallback via **`withReadStream: true`**).
- **Home:** banner **Edit** opens **`launchLocalVideoEdit`** (`local_video_edit_launcher.dart`) — bottom sheet **Device media** vs **Browse files** → **`POST /uploads/videos`** → **`EditVideoScreen.upload`**. Edit is available even when the downloads list is empty.
- **Models:** **`SelectedLocalVideo`**, **`LocalVideoPickKind`** (`features/edit/local_video/selected_local_video.dart`); picker helpers (`local_video_pickers.dart`). Large-file pre-check when **`sizeBytes`** is known; gallery **`content:`** URIs copied to temp via **`openRead`** stream (no full-file memory buffer).

### Phase C4 — pending

- **C4:** QA, RTL polish, release APK pass.

## Phase D — pending

- Preview polish, QA pass across upload + download sources; optional orphan DB cleanup if upload rows outlive deleted files.

---

## Manual checks — uploads (`curl`)

Replace `BASE`, `TOKEN`, and paths.

```bash
curl -sS -X POST "$BASE/uploads/videos" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@./sample.mp4;type=video/mp4"

curl -sS "$BASE/uploads/$UPLOAD_ID" -H "Authorization: Bearer $TOKEN"
curl -sS "$BASE/uploads/$UPLOAD_ID/file" -H "Authorization: Bearer $TOKEN" -o out.bin
```

---

## Manual checks — edit from upload (`curl`)

Use **`operations`** exactly as `backend/src/modules/edit/edit.schemas.ts` (e.g. trim + compress).

```bash
export BASE=https://api.example.com
export TOKEN=YOUR_DEVICE_BEARER

# A) Upload (save UPLOAD_ID from JSON uploadId)
curl -sS -X POST "$BASE/uploads/videos" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@./111.mp4;type=video/mp4"

export UPLOAD_ID=<paste-uploadId>

# B) Create edit from upload
curl -sS -X POST "$BASE/edits" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"sourceUploadId\":\"$UPLOAD_ID\",\"operations\":[{\"type\":\"trim\",\"startSec\":0,\"endSec\":10},{\"type\":\"compress\",\"preset\":\"social\"}]}"

export EDIT_ID=<paste-editJobId>

# C) Poll
curl -sS "$BASE/edits/$EDIT_ID" -H "Authorization: Bearer $TOKEN"

# D) Download output when status done / outputReady
curl -sS "$BASE/edits/$EDIT_ID/file" -H "Authorization: Bearer $TOKEN" -o edited.mp4

# E) Regression — edit from completed download (use real done job id)
export DOWNLOAD_JOB_ID=<your-done-download-uuid>
curl -sS -X POST "$BASE/edits" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"sourceDownloadJobId\":\"$DOWNLOAD_JOB_ID\",\"operations\":[{\"type\":\"trim\",\"startSec\":0,\"endSec\":5}]}"

# F) Negatives
curl -sS -X POST "$BASE/edits" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"sourceDownloadJobId\":\"$DOWNLOAD_JOB_ID\",\"sourceUploadId\":\"$UPLOAD_ID\",\"operations\":[{\"type\":\"mute\"}]}"
# expect EDIT_MULTIPLE_SOURCES

curl -sS -X POST "$BASE/edits" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"operations\":[{\"type\":\"mute\"}]}"
# expect EDIT_SOURCE_REQUIRED

curl -sS -X POST "$BASE/edits" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"sourceUploadId\":\"00000000-0000-4000-8000-000000000000\",\"operations\":[{\"type\":\"mute\"}]}"
# expect EDIT_UPLOAD_NOT_FOUND or JOB-like 404

# Cross-device: TOKEN_B must not edit TOKEN_A's UPLOAD_ID (use second device's token)
curl -sS -X POST "$BASE/edits" -H "Authorization: Bearer $TOKEN_B" -H "Content-Type: application/json" \
  -d "{\"sourceUploadId\":\"$UPLOAD_ID\",\"operations\":[{\"type\":\"mute\"}]}"
# expect EDIT_UPLOAD_NOT_FOUND
```

---

## Error codes (backend)

**Upload:** `UPLOAD_FILE_TOO_LARGE`, `UPLOAD_VIDEO_TOO_LONG`, `UPLOAD_UNSUPPORTED_TYPE`, `UPLOAD_INVALID_VIDEO`, `UPLOAD_FAILED`, `UPLOAD_NOT_FOUND`.

**Edit source:** `EDIT_SOURCE_REQUIRED`, `EDIT_MULTIPLE_SOURCES`, `EDIT_UPLOAD_NOT_FOUND`, `EDIT_UPLOAD_NOT_READY`, `EDIT_SOURCE_FILE_MISSING`; existing `EDIT_INVALID_SOURCE`, `EDIT_FAILED`, `EDIT_JOB_NOT_FOUND`, `JOB_NOT_FOUND`.
