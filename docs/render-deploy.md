# Deploying to Render (API + worker + DB + Redis)

This document complements optional [`render.yaml`](../render.yaml) in the repo root. Adjust **service names**, **plans**, and **repo URL** in the Render dashboard or blueprint.

## Critical: video storage

Render **persistent disks are attached per service**. The **API web service** and the **background worker** run as **separate services**, so they **do not share one local filesystem** unless you use a **single service** for both (not recommended here) or **external object storage**.

**Do not rely on ephemeral disk** for user videos: worker-written files under `STORAGE_DIR` must be readable by the API when serving `GET /downloads/:jobId/file`.

**Production next step:** use **S3-compatible storage** (Cloudflare R2, AWS S3, Backblaze B2, etc.), store object keys in your DB, and stream from presigned URLs or proxy through the API. Until then, single-node setups (Docker Compose on one VPS) or **one** Render service with disk may work for demos only.

If you still attach disks on Render:

- Mount the **same logical strategy** only works inside **one** container — not API + worker separately without shared storage.

## Recommended Render components

| Component | Render product |
|----------|----------------|
| HTTP API | **Web Service** (Docker or Node) |
| BullMQ worker | **Background Worker** (same image as API, different start command) |
| PostgreSQL | **Render Postgres** |
| Redis | **Render Key Value** (Redis-compatible URL as `REDIS_URL`) |

## Environment variables (both API and worker where applicable)

Set these in the dashboard (or blueprint `envVars`).

| Variable | Example | Notes |
|----------|---------|--------|
| `NODE_ENV` | `production` | |
| `PORT` | `3000` | Render sets `PORT`; ensure app listens on `process.env.PORT` (already does). |
| `DATABASE_URL` | *(from Postgres)* | Same DB for API and worker. |
| `REDIS_URL` | *(from Key Value)* | Same Redis for API and worker. |
| `STORAGE_DIR` | `/app/storage` | Must exist or your Dockerfile/workdir must create it; see disk warning above. |
| `ADMIN_TOKEN` | *(secret)* | Strong random string. |
| `DEVICE_TOKEN_SECRET` | *(secret)* | **Same value** on API and worker (signing device tokens). |
| `AUTO_REGISTER_DEVICES` | `true` | Allows open registration when paired with `REQUIRE_INVITE_CODE=false`. |
| `REQUIRE_INVITE_CODE` | `false` | Public APK flow without invite codes. |
| `DEFAULT_DAILY_LIMIT` | `20` | Per-device download daily cap (also referred to as download daily limit). |
| `ANALYZE_DAILY_LIMIT` | `200` | Global analyze cap per device/day on server. |
| `DOWNLOAD_CONCURRENCY` | `3` | Worker parallelism. |
| `COOKIES_FILE` | *(optional)* | Path to yt-dlp cookies file if used; omit if not needed in cloud. |

### Registration semantics

- `REQUIRE_INVITE_CODE=false` and `AUTO_REGISTER_DEVICES=true`: new devices can call `POST /devices/register` **without** `inviteCode`.
- `REQUIRE_INVITE_CODE=true`: `inviteCode` is required for **new** devices and for **existing** device token rotation.
- If `inviteCode` is sent (non-empty), the server validates it and increments invite usage for **new** devices as before.

## Docker images

The repo [`backend/Dockerfile`](../backend/Dockerfile) builds the API image. Use the **same image** for the worker with a **different command**:

- API: `sh -c "npx prisma migrate deploy && npm run start"` (or rely on image `CMD` after migrate in dashboard release command).
- Worker: `npm run worker`

**Important:** run **`prisma migrate deploy`** only on the **API** (or a one-off release job), not redundantly from every worker instance if you scale workers—typically one migrate per deploy is enough.

## Flutter Android release APK

Bake the public HTTPS origin:

```bash
cd mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Optional verbose download logs:

```bash
--dart-define=DOWNLOAD_DEBUG_LOGS=true
```

## Local parity

See [`backend/docker-compose.yml`](../backend/docker-compose.yml) and [`backend/.env.example`](../backend/.env.example) for `AUTO_REGISTER_DEVICES` / `REQUIRE_INVITE_CODE`.
