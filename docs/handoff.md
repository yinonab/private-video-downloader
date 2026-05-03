# Project Handoff — private-video-downloader

## IMPORTANT — current task (קרא קודם / read first)

**IMPORTANT CURRENT TASK**

- Do **not** add features.
- Do **not** refactor broadly.
- Do **not** work on iOS, dashboard, S3, thumbnails, cookies upload, billing, or user management.

**Current blocker**

`flutter --version` returns `command not found` (Flutter not installed on this machine or not on `PATH`; on Git Bash/WSL/Android Studio terminal check the same).

**Next goal**

Install Flutter on Windows → generate native Flutter project folders (`flutter create` inside `mobile/`) → patch `AndroidManifest.xml` → `flutter pub get` / `flutter analyze` → build release APK → install on a physical Android device → verify one full flow (register → analyze → download job → poll → save file → open/share) end-to-end.

**Where the details live in this doc**

Operational steps: **Next exact steps**, **Backend run**, **Testing order**, and **Prompt for new Cursor account** at the end.  
Full architecture & file map: **Agent knowledge supplement** below.  
Product scope & exclusions: **Product**, **Current priority**, and **Important instruction** still apply in full — nothing removed.

---

## Goal

Build a real installable Android MVP for a private video downloader app.

This is not only a backend project.
This is not a web dashboard project.
The immediate goal is a real Flutter Android app that can be installed on a phone as an APK.

## Product

The app should let the user share a video URL from apps like YouTube, TikTok, Instagram, Facebook, Threads, etc.

Flow:

1. User taps Share in another app.
2. User selects this app.
3. App receives the URL.
4. App sends URL to backend.
5. Backend analyzes URL.
6. User selects quality/format.
7. Backend downloads via yt-dlp/ffmpeg.
8. App shows progress.
9. App downloads final file.
10. User can open/share/save the file.

Manual paste URL flow is also required.

## Current priority

Focus only on Android MVP.

Do not work on:

* iOS Share Extension
* Admin dashboard
* S3/MinIO
* thumbnails
* cookies upload UI
* Telegram notifications
* billing
* user management
* extra polish

## Backend status

Backend exists under:

```text
backend/
```

Backend is Node.js / TypeScript / Fastify.

It includes:

* device registration
* invite codes
* deviceToken auth
* GET /devices/me
* POST /analyze
* POST /downloads
* GET /downloads
* GET /downloads/:id
* GET /downloads/:id/file
* retry
* delete
* Redis/BullMQ
* PostgreSQL/Prisma
* yt-dlp worker
* ffmpeg via yt-dlp
* Docker Compose
* admin API
* analyze/download rate limits

Backend lint passed previously.

## Mobile status

Flutter source exists or is being created under:

```text
mobile/
```

The mobile app should include:

* Register Device screen
* Home / Library screen
* Paste Link flow
* Analyze screen
* Quality selector
* Download Status screen
* Settings screen
* Android Share Intent handling
* File download/open/share

Important: android/ and ios/ folders may not exist yet because Flutter was not installed in the previous environment.

## Local machine status

On this machine, currently:

```bash
flutter --version
```

returns:

```text
bash: flutter: command not found
```

So the next step is to install Flutter and add it to PATH.

## Next exact steps

1. Install Flutter SDK for Windows.
2. Add Flutter to PATH.
3. Verify:

```bash
flutter --version
flutter doctor
```

4. Then run:

```bash
cd mobile
flutter create . --project-name private_video_downloader --org com.privatevideodownloader.app
flutter pub get
flutter analyze
flutter run
```

5. Patch AndroidManifest if needed:

* MainActivity must use `singleTop`
* exported must be true
* add SEND intent-filter for text/plain
* allow cleartext traffic for local HTTP backend during MVP

6. Build APK:

```bash
flutter build apk --release
```

APK output:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

## Backend run

From backend:

```bash
cp .env.example .env
docker compose up --build
```

Set secure values in `.env`:

* ADMIN_TOKEN
* DEVICE_TOKEN_SECRET

Create invite code through admin API.

## Testing order

1. Backend health from computer.
2. Backend health from phone browser.
3. Register device in app.
4. Paste URL manually.
5. Analyze.
6. Download.
7. Poll progress.
8. Open/share downloaded file.
9. Only then test Android Share from YouTube/TikTok/etc.

## Important instruction

Do not expand scope.
Do not add new features.
First make Android APK build, install, and complete one full download end-to-end.

---

## Agent knowledge supplement (full project map)

מקטע זה נכתב כדי של**איש קוד / חשבון Cursor אחר** יוכל להמשיך בלי הסתמכות על היסטוריית צ’אט. הוא מתאר מה קיים ב**ריפו** בזמן כתיבת ה-handoff.

This section mirrors the same structure in English for tooling/international teammates.

### Repository layout (what matters)

```text
private-video-downloader/
  README.md                 # Backend + Mobile quick-start (root)
  docs/
    handoff.md              # Continuity doc (this file)
  backend/
    docker-compose.yml      # Postgres, Redis, API, worker
    prisma/schema.prisma    # Device, InviteCode, Link, DownloadJob, FileAsset, EventLog…
    src/
      index.ts              # HTTP server bootstrap
      app.ts                # Fastify: plugins, routes, GET /health
      config.ts             # Env (PORT default 3000, limits, secrets)
      middleware/           # authDevice, authAdmin, errorHandler
      modules/
        devices/            # POST /devices/register, GET /devices/me
        analyze/            # POST /analyze
        downloads/          # Jobs + file streaming
        admin/              # prefix /admin
      plugins/              # prisma, redis, queues (BullMQ)
      workers/              # BullMQ consumer + yt-dlp download worker
      services/             # ytdlp, storage, hashing, rateLimit, urlSafety, platform…
      types/errors.ts       # AppError codes
  mobile/
    README.md               # Flutter build + Manifest snippet (detailed)
    pubspec.yaml
    lib/
      main.dart
      app.dart              # BootstrapCoordinator, MaterialApp, AppScope
      core/                 # api_client, local_session, models, widgets, theme, utils
      services/             # device/analyze/download + file_download + share_intent
      features/             # onboarding, home, analyze, download_status, settings
```

**חסר עד להרצת `flutter create`:** `mobile/android/**`, `mobile/ios/**`.

### Backend — נתיבי API (ללא קידומת `/api`)

מוגדרים ב־`backend/src/app.ts`:

| Method | Path | Auth | הערות |
|--------|------|------|--------|
| GET | `/health` | ללא | `{ ok: true }` |
| POST | `/devices/register` | ללא | גוף: `deviceId`, `inviteCode`, `platform`, אופציונלי `deviceName` |
| GET | `/devices/me` | Bearer מכשיר | כולל `dailyLimit` מה-DB ו־**`analyzeDailyLimit`** מ־`config.ANALYZE_DAILY_LIMIT` |
| POST | `/analyze` | Bearer מכשיר | גוף JSON `{ url }` — מחזיר מטא־דאטה + רשימת `availableFormats` קבועה |
| POST | `/downloads` | Bearer מכשיר | `{ url, format, quality? }` — פורמטים מורשים: `best`, `1080p`, `720p`, `audio_mp3` |
| GET | `/downloads` | Bearer מכשיר | רשימה + pagination |
| GET | `/downloads/:jobId` | Bearer מכשיר | פירוט + `file` כש־`done` |
| GET | `/downloads/:jobId/file` | Bearer מכשיר | בינארי (תומך Range) |
| POST | `/downloads/:jobId/retry` | Bearer מכשיר | רק `failed`/`canceled` |
| DELETE | `/downloads/:jobId` | Bearer מכשיר | 204 |
| — | `/admin/...` | Admin Bearer | קודי הזמנה וכו׳ |

**CORS:** `origin: true` — שימושי לכלי דפדפן; האפליקציה משתמשת ב־Dio.

**כלל מקביליות (שרת):** אי־אפשר ליצור הורדה חדשה אם למכשיר כבר יש job ב־`queued`/`running` (409 `CONFLICT`).

### Backend — ישויות (Prisma)

מסכם: `Device` ← `DownloadJob` → `Link`; `DownloadJob` ← `FileAsset`; `InviteCode` נפרד. פירוט בשדות ב־`prisma/schema.prisma`.

### Mobile — ארכיטקטורה

- **`BootstrapCoordinator`** (`app.dart`): `LocalSession`, `ApiClient`, האזנה ל־`ShareIntentService`, ו־`routeSharedAnalyze` דוחף `AnalyzeScreen`.
- **`AppScope`** (`core/app_scope.dart`): `InheritedWidget` — גישה בכל המסכים דרך `AppScope.read(context)`.
- **`LocalSession`**: SharedPreferences ל־URL שרת + אינדקס נתיבי קבצים מקומיים; SecureStorage ל־`deviceId` ו־`deviceToken`; `pendingSharedUrl` לשיתוף לפני רישום.
- **`ApiClient`**: Dio + interceptor Bearer; **לא** שולח Authorization ב־`/devices/register`; רישום ל־URL מוחלט `{server}/devices/register`.
- **`ShareIntentService`**: `receive_sharing_intent` — cold + stream; חילוץ URL; אם לא רשום — `stageSharedUrl`, אחרת ניווט ל־Analyze.
- **קבצים מקומיים:** הורדות ל־`getApplicationDocumentsDirectory()/downloads/` + שמירת path ב prefs (`FileDownloadService`).

### Mobile — תלויות עיקריות (`pubspec.yaml`)

`dio`, `flutter_secure_storage`, `shared_preferences`, `receive_sharing_intent`, `path_provider`, `open_filex`, `share_plus`, `uuid`, `intl`, `path`, `flutter_localizations` (SDK).

### מצב מימוש (אמת לריפו)

| רכיב | סטטוס |
|------|--------|
| מסכי Dart + שירותים + מודלים | ממומשים תחת `mobile/lib/` |
| `android/` / Gradle / Manifest | **חובה להריץ `flutter create` ולתקן Manifest** לפי `mobile/README.md` |
| בדיקת APK על מכשיר | לא בוצעה בסביבת העבודה הקודמת (אין Flutter ב־PATH) |

### משתני סביבה חובה (Backend)

ראו `backend/src/config.ts` + `.env.example`: `DATABASE_URL`, `REDIS_URL`, `STORAGE_DIR`, `ADMIN_TOKEN`, `DEVICE_TOKEN_SECRET` (+ אופציונלי `COOKIES_FILE`).

### Backend — תמונה מערכתית (pipeline, סיכום קצר)

- הרשאת מכשיר: Bearer → hash מול `DEVICE_TOKEN_SECRET` → `Device` חייב `status === "active"`.
- `POST /analyze`: שומר מטא־דאטה ב־`Link` (דרך שירות הניתוח).
- `POST /downloads`: יוצר `DownloadJob`, מגביר מונה הורדות יומי (Redis), דוחף משימה ל־BullMQ.
- Worker (`workers/download.worker.ts`): מריץ yt-dlp, יוצר קבצים תחת `STORAGE_DIR`, מקשר `FileAsset`.
- `GET …/file`: מזרים קובץ מהדיסק עם `Content-Disposition` / Range.

### Backend — בדיקות / איכות קוד

```bash
cd backend && npm run lint
```

(מפותח כ־`tsc --noEmit` לפי `package.json`; עבר בעבר בפרויקט.)

### Mobile — מפת קבצים (`lib/`) לפי תפקיד

| נתיב | תפקיד |
|------|--------|
| `main.dart` | `initializeDateFormatting`, מגבלות מסך, `BootstrapCoordinator.bootstrap()`, `runApp` |
| `app.dart` | `BootstrapCoordinator`, `PrivateDownloaderApp`, `ListenableBuilder` על `session`, `MaterialApp` (RTL builder, `he_IL`, themes), `routeSharedAnalyze` |
| `core/network/api_client.dart` | כל קריאות HTTP + `downloadFileToDisk` ל־`/file` |
| `core/storage/local_session.dart` | מפתחות אחסון, `bootstrap`, `applyRegistration`, `factoryResetLocal`, `stageSharedUrl` / `consumePendingShare`, `rememberDownloadPath` |
| `core/models/*` | פרסור JSON סביל־null; `CreateDownloadResponse` תומך גם ב־`jobId` גם ב־`id` |
| `services/share_intent_service.dart` | חיבור Android share |
| `services/file_download_service.dart` | Dio download → `documents/downloads/`, שם קובץ מנוקה ומניעת התנגשויות |
| `features/onboarding/register_device_screen.dart` | קלט שרת + invite + שם מכשיר; `DeviceService.register` |
| `features/home/home_screen.dart` | רשימה, pull-to-refresh, הדבקה, פתיחת סטטוס, מחיקה, retry, פתיחה/שיתוף קובץ מקומי אם קיים |
| `features/home/download_card.dart` | כרטיס job + תפריט קצר |
| `features/analyze/analyze_screen.dart` | `POST /analyze`, בחירת איכות, `POST /downloads`, `pushReplacement` למסך סטטוס |
| `features/analyze/quality_selector.dart` | UI בחירת פורמט |
| `features/download_status/download_status_screen.dart` | `Timer.periodic(2s)` ל־`GET /downloads/:id` עד terminal; כפתורים הורדה/פתיחה/שיתוף + retry |
| `features/settings/settings_screen.dart` | `GET /devices/me`, איפוס מקומי |

### Mobile — מפת זרימת מסכים

1. אם לא `session.isRegistered` → `RegisterDeviceScreen`.
2. אחרי הצלחה → `HomeScreen` (+ `consumePendingShare` במסגרת טעינה ראשונה → Analyze אם צריך).
3. הדבקה / Share → `AnalyzeScreen` → `DownloadStatusScreen` (עם `jobId`).
4. `SettingsScreen` מה־Home.

### Mobile — טיפול שגיאות

- **`ApiError`**: מתרגמת `error.code/message` מהשרת למחרוזות עבריות נפוצות (`core/models/api_error.dart`).

### מלכודות והמלצות

- טלפון פיזי: כתובת השרת היא **LAN IP של המחשב**, לא `localhost`; אמולטור Android: **`10.0.2.2`** לפורט השרת.
- HTTP בשכבת MVP: עלול להידרש `usesCleartextTraffic`/Network Security Config ב־Android.
- `flutter create .` בתוך `mobile/` עלול לגעת ב־`pubspec.yaml` — להשוות diff לפני commit.
- אין להרחיב scope (ראו סעיפי Out of scope בהמשך למעלה במסמך).

---

## Prompt for new Cursor account

Start with section **IMPORTANT — current task** at the top of this file, then follow **Next exact steps** and the supplement as needed.

Read `@docs/handoff.md` and continue exactly from there.

Do not expand scope.
Do not add new features.
Focus only on installing Flutter, generating the Android Flutter project, building the APK, and testing Android MVP end-to-end.

The current blocker is:

```bash
flutter --version
```

returns:

```text
bash: flutter: command not found
```

So the next step is Flutter installation and PATH setup on Windows/Git Bash.
