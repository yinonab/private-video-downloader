# Local video editing — phased plan

Concise roadmap for **device-local video** as an edit source (server-side ffmpeg only; no on-device ffmpeg).

## Phase A (backend) — done in repo

- **Model:** `UploadedMedia` (Prisma); **not** a `DownloadJob`.
- **Upload:** `POST /uploads/videos` — single multipart field `file`, streamed to temp → **ffprobe** validate → final path `devices/<deviceId>/uploads/<uploadId>/source.<ext>`; optional **`thumbnail.jpg`** via server **ffmpeg** (upload still succeeds if thumbnail fails).
- **Read:** `GET /uploads/:id`, `GET /uploads/:id/file`, `GET /uploads/:id/thumbnail` (404 + `UPLOAD_NOT_FOUND` when thumbnail absent).
- **Limits:** **175MB**, **420s** duration (env: `MAX_LOCAL_VIDEO_UPLOAD_MB`, `MAX_LOCAL_VIDEO_UPLOAD_DURATION_SECONDS`).
- **Retention:** **120 minutes** on disk under `*/uploads/*` (`UPLOAD_RETENTION_MINUTES` in cleanup container). Other paths keep **`MEDIA_RETENTION_MINUTES`** (e.g. 30). Edited outputs remain under `devices/<deviceId>/edits/`.

## Phase B (mobile)

- File picker + multipart upload client; map API errors (`UPLOAD_*` codes).

## Phase C (edit integration)

- Extend **Quick Edit** / `POST /edits` (or parallel flow) to accept an **upload id** as source; worker reads upload storage keys (similar to download source resolution).

## Phase D (polish)

- Orphan **DB** cleanup if files expire before rows (optional); metrics; stricter container policy if needed.

---

## Manual checks (curl)

Replace `BASE`, `TOKEN`, and paths.

```bash
# Upload (valid short mp4)
curl -sS -X POST "$BASE/uploads/videos" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@./sample.mp4;type=video/mp4"

# Metadata
curl -sS "$BASE/uploads/$UPLOAD_ID" -H "Authorization: Bearer $TOKEN"

# Thumbnail (404 if generation failed)
curl -sS -D - "$BASE/uploads/$UPLOAD_ID/thumbnail" -H "Authorization: Bearer $TOKEN" -o /dev/null

# File (video stream)
curl -sS "$BASE/uploads/$UPLOAD_ID/file" -H "Authorization: Bearer $TOKEN" -o out.bin

# Too large (expect UPLOAD_FILE_TOO_LARGE — multipart plugin / stream cap)
curl -sS -X POST "$BASE/uploads/videos" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@./huge.bin;type=video/mp4"

# Invalid (expect UPLOAD_INVALID_VIDEO or UPLOAD_UNSUPPORTED_TYPE)
curl -sS -X POST "$BASE/uploads/videos" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@./empty.txt;type=video/mp4"
```

---

## Error codes (backend)

| Code | Typical HTTP |
|------|----------------|
| `UPLOAD_FILE_TOO_LARGE` | 413 |
| `UPLOAD_VIDEO_TOO_LONG` | 400 |
| `UPLOAD_UNSUPPORTED_TYPE` | 415 |
| `UPLOAD_INVALID_VIDEO` | 400 |
| `UPLOAD_FAILED` | 500 |
| `UPLOAD_NOT_FOUND` | 404 |
