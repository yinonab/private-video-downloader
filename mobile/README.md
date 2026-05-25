# Private Video Downloader — אפליקציית Flutter (Android MVP)

אפליקציית לקוח ל־API הקיים. מומלץ לפתוח את התיקייה `mobile` ב־IDE כפרויקט Flutter.

## A. יצירת תיקיות Native (אם חסרות)

אם אין עדיין תיקיות `android/` או `ios/` (למשל אחרי ששכפלתם רק את `lib/`):

```bash
cd mobile
flutter create . --project-name private_video_downloader --org com.privatevideodownloader.app
```

פקודה זו **לא** דורסת את `lib/` הקיים, אך עשויה לעדכן קבצים כמו `pubspec.yaml` — בדקו diff לפני commit.

## B. התקנת תלויות

```bash
cd mobile
flutter pub get
```

## C. הרצה

```bash
cd mobile
flutter run
```

בחרו מכשיר Android או אמולטור מחובר.

## D. בניית APK (Release)

ברירת המחדל בייצור היא **`https://api.linkclip.win`** (גם בלי `--dart-define`). אפשר לעקוף עם:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

לבדיקות מורכבות של הורדות לקובץ אפשר להפעיל לוגים מפורטים:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com \
  --dart-define=DOWNLOAD_DEBUG_LOGS=true
```

## E. מיקום קובץ ה־APK

```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

## F. פיתוח מקומי (שרת LAN / אמולטור)

כשלא מועבר `API_BASE_URL`, ברירת המחדל היא כתובת ייצור מהחבילה (**`https://api.linkclip.win`**). תוספת בשמירה ב־`SharedPreferences` **לא מחליפה** את ברירת המחדל בלי שהמשתמש מפעיל במפורש את מצב **שרת מותאם** במסך ההגדרות (**מתקדם / מפתחים**) ושומר כתובת.

- **טלפון פיזי ומחשב על אותה רשת Wi‑Fi:**  
  `http://<LAN-IP-של-המחשב>:<פורט>`  
  לדוגמה: `http://192.168.1.10:3000`  
  **אל תשתמשו ב־`localhost` מהטלפון** — זה מתייחס לטלפון עצמו, לא למחשב.

- **אמולטור Android (Android Studio):**  
  `http://10.0.2.2:3000`  
  (גישה מותאמת ל־host של המחשב מהאמולטור.)

- אם השרת רץ ב־HTTP בלבד, ייתכן שתצטרכו לאפשר **cleartext traffic** ב־`android/app/src/main/AndroidManifest.xml` (למשל `android:usesCleartextTraffic="true"` בתוך `<application>`) — רק לבדיקות מקומיות.

**מתקדם:** בהגדרות האפליקציה → «מתקדם / מפתחים» ניתן להזין שרת ידני ולבצע רישום מחדש.

מסך הרישום הראשון מציג טקסט הסבר, שורת שרת קריאה־בלבד לכתובת ברירת המחדל, והכפתור **רישום מכשיר**; אין שדות ריקים. קוד הזמנה (אופציונלי) מוצג רק אחרי הקישור «יש לך קוד הזמנה?». בחירת שפה זמינה גם מהסרגל העליון וגם מההגדרות.

לביצוע **רישום מכשיר** מהמסך הראשון (בלי קוד הזמנה), המשתמש לוחץ על «רישום מכשיר»; השרת צריך `AUTO_REGISTER_DEVICES=true` ו־`REQUIRE_INVITE_CODE=false` — ראו `backend/.env.example`.

## G. תפריט Share ב־Android (העברת קישור `text/plain`)

אחרי `flutter create`, בקובץ `android/app/src/main/AndroidManifest.xml`, בתוך ה־`<activity>` של `MainActivity`:

1. הגדירו (או וודאו):
   - `android:launchMode="singleTop"`
   - `android:exported="true"` (נדרש ל־intent filters חיצוניים)

2. הוסיפו **בנוסף** ל־launcher intent-filter, את המקטע הבא:

```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```

השאירו גם את ה־intent-filter הרגיל של `MAIN` / `LAUNCHER` כדי שהאייקון יישאר במגש האפליקציות.

## H. הרצת Backend (Docker)

```bash
cd backend
cp .env.example .env
docker compose up --build
```

(כוונו את כתובת השרת באפליקציה בהתאם לפורט שמוגדר ב־`.env`.)

## I. יצירת קוד הזמנה (Invite)

עם טוקן אדמין תקף:

```bash
curl -X POST http://localhost:3000/admin/invite-codes \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"maxUses":10}'
```

---

## זרימת MVP בקצרה

1. מסך ראשון: רישום מכשיר (`POST /devices/register`) עם כתובת שרת וקוד הזמנה.  
2. **שיתוף קישור** מיישום אחר — נפתח מסך ניתוח (`POST /analyze`) או נשמר לרגע האחרון אם עדיין לא נרשמתם.  
3. בחירת איכות והתחלת הורדה (`POST /downloads`).  
4. מסך סטטוס — קריאה ל־`GET /downloads/:id` כל ~2 שניות.  
5. כשהסטטוס `done`: הורדה לקבצים תחת `documents/downloads/`, פתיחה ושיתוף.

## הערות סביבת פיתוח

בסביבה זו **לא זוהה** Flutter/Dart ב־PATH — יש להריץ את פקודות `flutter` / `dart analyze` מקומית על מכונה עם Flutter Stable מותקן.
