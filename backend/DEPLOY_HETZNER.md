# Deploy LinkClip backend on Hetzner (Docker Compose + Caddy)

Production API URL: **https://api.linkclip.win**

Target: **Hetzner Cloud VPS**, Ubuntu 24.04, public IPv4 **46.225.161.190**.

## Network & security

| Exposure | Notes |
|---------|--------|
| **DNS** | `A` record `api` → `46.225.161.190` (DNS only / no CDN proxy required for Let’s Encrypt HTTP-01). |
| **Firewall** | Allow **TCP 22**, **TCP 80**, **TCP 443**, **ICMP** only. |
| **Do not publish** | API **3000**, Postgres **5432**, Redis **6379** to the internet. Production Compose keeps them on the internal Docker network; only **Caddy** binds **80** and **443**. |

Temporary media lives under the **`downloads_data`** volume (`/app/storage` in API/worker/cleanup). It is not long-term storage. **Cleanup** removes files whose modification time is older than **`MEDIA_RETENTION_MINUTES`** (default **30** minutes). Thirty minutes is safer initially than a few minutes (fewer accidental deletes while jobs finish or clients retry).

## Prerequisites on the server

- Docker Engine + Docker Compose plugin (`docker compose`).
- Git or rsync to place this repo (at least the `backend/` tree).
- Domain **api.linkclip.win** pointing at the VPS before TLS issuance.

## Upload code

**Option A — git**

```bash
ssh root@46.225.161.190
git clone <your-repo-url> linkclip
cd linkclip/backend
```

**Option B — rsync** (from your machine)

```bash
rsync -avz --exclude node_modules --exclude dist ./backend/ root@46.225.161.190:/opt/linkclip/backend/
ssh root@46.225.161.190 "cd /opt/linkclip/backend && ..."
```

## Environment files (no secrets in git)

1. **Compose `.env`** (Postgres password — loaded automatically by `docker compose`):

   ```bash
   cd /path/to/backend
   cp .env.example .env
   nano .env   # set POSTGRES_PASSWORD
   ```

2. **`.env.production`** (API + worker):

   ```bash
   cp .env.production.example .env.production
   nano .env.production
   ```

   Set **`DATABASE_URL`** so the password matches **`POSTGRES_PASSWORD`** in `.env`:

   `postgresql://linkclip:<same-password>@postgres:5432/linkclip`

## Generate secrets

```bash
openssl rand -base64 32   # example entropy
openssl rand -base64 48
openssl rand -hex 32
```

Use strong random values for **`DEVICE_TOKEN_SECRET`** and **`ADMIN_TOKEN`** in `.env.production`.

## Cookies file (yt-dlp)

```bash
mkdir -p secrets/cookies
touch secrets/cookies/global.txt
chmod 600 secrets/cookies/global.txt
# Paste Netscape-format cookies if needed; leave empty if unused
```

Compose mounts **`./secrets`** read-only into API and worker at **`/app/secrets`**. **`COOKIES_FILE`** must match that path (see `.env.production.example`).

## Start production stack

```bash
cd /path/to/backend
docker compose -f docker-compose.prod.yml up -d --build
```

## Logs

```bash
docker compose -f docker-compose.prod.yml logs -f caddy api worker
```

## Health check

```bash
curl -fsS https://api.linkclip.win/health
```

## Test device registration

```bash
curl -X POST https://api.linkclip.win/devices/register \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"prod-test-device-001","deviceName":"Prod Test Android","platform":"android"}'
```

## LinkClip Android APK (Flutter)

Build with the production API base URL:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.linkclip.win
```

## Files involved

| File | Role |
|------|------|
| `docker-compose.prod.yml` | Caddy, API, worker, cleanup, Postgres, Redis |
| `Caddyfile` | HTTPS + reverse proxy to `api:3000` |
| `.env` | `POSTGRES_PASSWORD` for Compose |
| `.env.production` | Runtime env for API/worker |
| `secrets/cookies/global.txt` | Optional cookies for yt-dlp |

## Validation on your machine (optional)

From `backend/`:

```bash
cp .env.example .env
cp .env.production.example .env.production
# Edit `.env` (POSTGRES_PASSWORD) and `.env.production` (secrets + DATABASE_URL password matching Postgres).

docker compose -f docker-compose.prod.yml config
npm run build
```

Docker Compose reads **`POSTGRES_PASSWORD`** from the project **`.env`** file for variable substitution. **`env_file: .env.production`** must exist on disk before `docker compose config` or `up` (copy from the example first).

Do not run `docker compose ... up` for production locally unless you intentionally mirror prod env and volumes.
