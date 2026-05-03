# Private video downloader — מוצר מלא

## Backend (Docker)

```bash
cd backend
cp .env.example .env      # הגדר ADMIN_TOKEN ארוך, DEVICE_TOKEN_SECRET ארוך
docker compose up --build # API ב־localhost:3000
```

יצירת קוד הזמנה:

```bash
curl -s -X POST http://localhost:3000/admin/invite-codes ^
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" ^
  -H "Content-Type: application/json" ^
  -d "{}"
```

(ב־bash החלף `^` ב־`\\`.)

לאחר הפעלה, פתח את האפליקציה והזן את **קוד ההזמנה** שקיבלת מ־`/admin/invite-codes` (לא `ADMIN_TOKEN`).

## Mobile (Flutter)

התיקייה `mobile/` מכילה קוד Flutter מלא.**עדיין אין בה קבצי פלטפורמה שנוצאים עם `flutter create`** (Gradle + Xcode עם wrapper). אחרי התקנת [Flutter SDK](https://flutter.dev):

```bash
cd mobile
flutter pub get
flutter create . --project-name private_video_downloader --org com.privatevideodownloader.app
flutter run
```

זה משלים באופן הרשמי את `android/` ו־`ios/` לצד הקבצים שנוספו ב־`lib/`.

חובה: אחרי `flutter create`, הוסף ב־`android/app/src/main/AndroidManifest.xml` בתוך `MainActivity` גם מסננת שיתוף טקסט:

```xml
<intent-filter>
    <action android:name="android.intent.action.SEND"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:mimeType="text/plain"/>
</intent-filter>
```

ומומלץ `android:launchMode="singleTop"` על אותה `activity`.

### iOS (שלב מתקדם)

שיתוף מממשק השיתוף ב־iOS דורש Share Extension כפי שבאיפיון (Phase 4). עד השלמת ההרחבה, ניתן להדביק קישור מהמשבצת או מלוח ההעתקה מתוך האפליקציה.
