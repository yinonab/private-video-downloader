// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'LinkClip';

  @override
  String get bootstrapPreparingApp => 'מכינים את האפליקציה…';

  @override
  String get bootstrapConnectingServer => 'מתחברים לשרת…';

  @override
  String get bootstrapConnectionFailed => 'לא הצלחנו להתחבר לשרת';

  @override
  String get bootstrapConnectionHint => 'בדוק חיבור לאינטרנט ונסה שוב.';

  @override
  String get bootstrapRetry => 'נסה שוב';

  @override
  String get bootstrapAdvancedSettings => 'הגדרות מתקדמות';

  @override
  String get languageSelectButton => 'בחר שפה';

  @override
  String get languageSelectTitle => 'בחר שפה';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrewOption => 'עברית';

  @override
  String get languageSectionTitle => 'שפה';

  @override
  String get appearance => 'מראה';

  @override
  String get themeSystem => 'לפי המערכת';

  @override
  String get themeLight => 'בהיר';

  @override
  String get themeDark => 'כהה';

  @override
  String get homeTitle => 'LinkClip';

  @override
  String get homeHeroTitle => 'הורדת סרטונים בקלות';

  @override
  String get homeHeroSubtitle => 'שתף סרטון או הדבק קישור כדי להתחיל.';

  @override
  String get homeHeroSubtitleCompact => 'שתף סרטון או הדבק קישור כדי להתחיל.';

  @override
  String get homeShareTip =>
      'טיפ: באינסטגרם, פייסבוק או טיקטוק לחץ Share ובחר את LinkClip.';

  @override
  String get homePasteLinkFab => 'הדבק קישור';

  @override
  String get homePasteLinkShort => 'הדבק קישור כאן';

  @override
  String get homeRecentDownloads => 'הורדות אחרונות';

  @override
  String get homeLoading => 'טוען…';

  @override
  String get homeErrorGeneric => 'אירעה שגיאה לא צפויה.';

  @override
  String get homeRetry => 'נסה שוב';

  @override
  String get homeEmptyTitle => 'אין הורדות עדיין';

  @override
  String get homeEmptySubtitle => 'סרטונים שתשתף או תדביק יופיעו כאן.';

  @override
  String get homePasteLinkButton => 'הדבק קישור';

  @override
  String get homeInvalidLink => 'הקישור לא תקין.';

  @override
  String get homePasteDialogTitle => 'הדבק קישור';

  @override
  String get homePasteDialogHint => 'מדביקים כאן את הקישור מהאפליקציה המקורית.';

  @override
  String get homeCancel => 'ביטול';

  @override
  String get homeContinue => 'המשך';

  @override
  String get homeDeleteDownloadTitle => 'למחוק הורדה?';

  @override
  String get homeDeleteConfirm => 'מחק';

  @override
  String get downloadCardStatusDetails => 'פירוט הסטטוס';

  @override
  String get downloadCardRetry => 'נסה שוב';

  @override
  String get downloadCardDelete => 'מחק';

  @override
  String durationChip(String duration) {
    return 'משך $duration';
  }

  @override
  String get analyzeTitle => 'ניתוח קישור';

  @override
  String get analyzeLoading => 'מנתח את הסרטון…';

  @override
  String get analyzeVideoFound => 'נמצא סרטון';

  @override
  String get analyzeChooseQuality => 'בחר איכות';

  @override
  String get analyzePrepareDownload => 'הכן להורדה';

  @override
  String get analyzeMissingLink => 'חסר קישור.';

  @override
  String get analyzeQualityUnavailableSnack =>
      'איכות זו אינה זמינה לסרטון הזה.';

  @override
  String get formatBestMp4 => 'Best MP4';

  @override
  String get format1080pMp4 => '1080p MP4';

  @override
  String get format720pMp4 => '720p MP4';

  @override
  String get format480pMp4 => '480p MP4';

  @override
  String get formatAudioMp3 => 'Audio MP3';

  @override
  String get qualityTikTokReady => 'מתאים לטיק טוק';

  @override
  String get qualityTikTokReadyDescription =>
      'מותאם לטיק טוק ולאפליקציות חברתיות. עשוי לקחת יותר זמן.';

  @override
  String get qualityTikTokReadyBadge => 'מומלץ להעלאה';

  @override
  String get downloadPreparingTikTokReadyTitle => 'מכינים סרטון מותאם לטיק טוק';

  @override
  String get downloadPreparingTikTokReadySubtitle =>
      'הסרטון עובר התאמה לטיק טוק ולאפליקציות חברתיות. זה עשוי לקחת כמה דקות.';

  @override
  String get downloadChipTikTokReady => 'מותאם לטיק טוק';

  @override
  String get qualityUnavailableForVideo => 'לא זמין לסרטון הזה';

  @override
  String get downloadStatusTitle => 'סטטוס הורדה';

  @override
  String get downloadStatusQueued => 'בתור';

  @override
  String get downloadStatusRunning => 'מכינים את הסרטון…';

  @override
  String get downloadStatusDone => 'מוכן לשמירה';

  @override
  String get downloadStatusFailed => 'ההורדה נכשלה';

  @override
  String get downloadStatusCanceled => 'בוטל';

  @override
  String get downloadStatusUnknown => 'לא ידוע';

  @override
  String get downloadVideoReadyHint => 'הסרטון מוכן להורדה למכשיר.';

  @override
  String downloadSpeed(String speed) {
    return 'מהירות: $speed';
  }

  @override
  String downloadEta(String eta) {
    return 'זמן משוער: $eta';
  }

  @override
  String get downloadRetry => 'נסה שוב';

  @override
  String get downloadSaveToDevice => 'שמור למכשיר';

  @override
  String get downloadOpen => 'פתח';

  @override
  String get downloadShare => 'שתף';

  @override
  String get downloadSavedToDownloads => 'הקובץ נשמר בתיקיית ההורדות';

  @override
  String get downloadSavedInAppOnly =>
      'הקובץ נשמר באפליקציה, אך לא ניתן לשמור לתיקיית ההורדות';

  @override
  String get downloadSavedGeneric => 'הקובץ נשמר';

  @override
  String get untitledVideo => 'ללא כותרת';

  @override
  String get unknownPlatform => 'לא ידוע';

  @override
  String get errorNetwork => 'שגיאת רשת. נסה שוב.';

  @override
  String get errorBadRequest => 'בקשה לא תקינה.';

  @override
  String get errorUnsupportedQuality =>
      'האיכות שנבחרה אינה נתמכת. נסה לבחור איכות אחרת.';

  @override
  String get errorNoSharedLink => 'לא נמצא קישור לשיתוף.';

  @override
  String get errorUnexpected => 'אירעה שגיאה לא צפויה.';

  @override
  String get errorUnauthorized => 'אין הרשאה לפעולה.';

  @override
  String get errorInvalidUrl => 'הקישור לא תקין.';

  @override
  String get errorRateLimited => 'הגעת למגבלה היומית.';

  @override
  String get errorConflict => 'הורדה אחרת כבר מתבצעת במכשיר.';

  @override
  String get errorJobNotFound => 'ההורדה לא נמצאה.';

  @override
  String get errorFileNotFound => 'הקובץ לא נמצא.';

  @override
  String get errorAnalyzeFailed => 'לא ניתן לנתח את הקישור.';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsServerUrl => 'כתובת שרת';

  @override
  String get settingsDeviceId => 'מזהה מכשיר';

  @override
  String get settingsRefreshDevice => 'רענון נתוני מכשיר';

  @override
  String get settingsAdvancedDevelopers => 'מתקדם / מפתחים';

  @override
  String get settingsAdvancedCustomSubtitle => 'שרת מותאם אישית';

  @override
  String get settingsAdvancedDefaultSubtitle => 'שרת ברירת מחדל מהאפליקציה';

  @override
  String get settingsServerFieldLabel => 'כתובת שרת (LAN / בדיקות)';

  @override
  String get settingsServerFieldHint => 'https://… או http://192.168.x.x:3000';

  @override
  String get settingsSaveCustomServer => 'שמור שרת מותאם והתחבר מחדש';

  @override
  String get settingsRevertToBakedServer => 'חזרה לשרת המוגדר בגרסת האפליקציה';

  @override
  String get settingsAdvancedFooterNote =>
      'גרסת ייצור רגילה משתמשת בכתובת המוטמעת ב־APK. כאן רק לפיתוח או שרת זמני.';

  @override
  String get settingsFactoryResetTitle => 'איפוס אפליקציה';

  @override
  String get settingsFactoryResetBody =>
      'פעולה זו תמחק את ההתחברות וההיסטוריה המקומית שמורים במכשיר.';

  @override
  String get settingsFactoryResetConfirm => 'איפוס';

  @override
  String get settingsEnterServerSnack => 'נא להזין כתובת שרת.';

  @override
  String get settingsInvalidServerSnack => 'כתובת השרת לא תקינה.';

  @override
  String get settingsServerUpdatedSnack =>
      'השרת עודכן. מתבצע רישום מחדש אוטומטית.';

  @override
  String get settingsNoBakedUrlSnack => 'אין כתובת שרת מוטמעת בגרסה זו.';

  @override
  String get settingsRevertSnack => 'חוזרים לשרת המוגדר בגרסת האפליקציה.';

  @override
  String get settingsEmptyPlaceholder => '(ריק)';

  @override
  String get registerTitle => 'רישום מכשיר';

  @override
  String get registerSettingsTooltip => 'הגדרות';

  @override
  String get registerServerSection => 'שרת';

  @override
  String get registerServerNotSet => '(לא מוגדר)';

  @override
  String get registerServerBakedHint =>
      'כתובת השרת נקבעה בגרסת האפליקציה. לשינוי — הגדרות ← מתקדם.';

  @override
  String get registerServerUrlLabel => 'כתובת שרת';

  @override
  String get registerInviteOptional => 'קוד הזמנה (אופציונלי)';

  @override
  String get registerDeviceNameOptional => 'שם מכשיר (אופציונלי)';

  @override
  String get registerSubmit => 'רישום מכשיר';

  @override
  String get registerValidationRequired => 'חובה';

  @override
  String get registerValidationBadUrl => 'כתובת לא תקינה';

  @override
  String get registerNeedServer =>
      'נא להזין כתובת שרת תקינה או לעדכן בהגדרות מתקדמות.';

  @override
  String get registerInvalidServerHost => 'כתובת השרת לא תקינה.';

  @override
  String get autoRegisterTitle => 'התחברות';

  @override
  String get autoRegisterConnecting => 'מתחבר לשרת…';

  @override
  String get autoRegisterFailedGeneric => 'ההתחברות נכשלה';

  @override
  String get autoRegisterManualSetup => 'הגדרה ידנית / מתקדם';

  @override
  String get downloadJobErrorGeneric =>
      'לא ניתן להוריד את הסרטון הזה בפורמט זמין.';

  @override
  String get downloadJobErrorQuality =>
      'האיכות שנבחרה לא זמינה לסרטון הזה. נסה איכות אחרת או Best MP4.';

  @override
  String get downloadJobErrorNormalizeFailed =>
      'לא ניתן להכין את הסרטון לפורמט נתמך.';

  @override
  String get shareNoLinkInContent => 'לא נמצא קישור לשיתוף';

  @override
  String get settingsMeStatusLabel => 'סטטוס במערכת';

  @override
  String get settingsMeNameLabel => 'שם במערכת';

  @override
  String get settingsMeDailyDownloadsLabel => 'מגבלת הורדות יומית';

  @override
  String get settingsMeDailyAnalyzeLabel => 'מגבלת ניתוח יומית';

  @override
  String get savedMustDownloadFirst => 'יש להוריד את הקובץ למכשיר תחילה.';

  @override
  String get savedCannotOpenFile => 'לא ניתן לפתוח את הקובץ.';

  @override
  String get savedCannotShareFile => 'לא ניתן לשתף את הקובץ.';

  @override
  String get savedShareFailedHint =>
      'השיתוף נכשל. נסה לפתוח את הקובץ או לשתף מתיקיית הקבצים.';

  @override
  String analyzeDurationLabel(String duration) {
    return 'משך $duration';
  }

  @override
  String get shareAnalyzingVideo => 'מנתח סרטון משותף…';

  @override
  String get shareLinkFound => 'נמצא קישור משותף';

  @override
  String get loadingAnalyzingDot => 'מנתח…';

  @override
  String get loadingPreparingDownloadDot => 'מכין הורדה…';

  @override
  String get loadingDownloadingDot => 'מוריד…';

  @override
  String get loadingSavingToDeviceDot => 'שומר למכשיר…';

  @override
  String get loadingFinalizingDot => 'מסיים…';

  @override
  String get downloadStageQueued => 'בתור';

  @override
  String get downloadStagePreparing => 'מכין…';

  @override
  String get downloadStageDownloading => 'מוריד…';

  @override
  String get downloadStageFinalizing => 'מסיים…';

  @override
  String get downloadStageReadyServer => 'מוכן — שמור במכשיר';

  @override
  String get downloadStageFailed => 'נכשל';

  @override
  String get downloadStageCanceled => 'בוטל';

  @override
  String get downloadStageUnknown => 'מעבד…';

  @override
  String downloadPercentValue(int percent) {
    return '$percent%';
  }

  @override
  String get downloadStatusSavedOnDeviceTitle => 'נשמר במכשיר';

  @override
  String get downloadStatusLoadingJob => 'טוען הורדה…';

  @override
  String get stageQueued => 'ממתין בתור';

  @override
  String get stagePreparing => 'מכינים את הסרטון...';

  @override
  String get stageDownloading => 'מוריד...';

  @override
  String get stageCheckingCompatibility => 'בודק תאימות וידאו...';

  @override
  String get stageRemuxing => 'מכינים את הסרטון...';

  @override
  String get stageNormalizingAudio => 'מייעלים את האודיו...';

  @override
  String get stageFullTranscoding => 'מעבד את הסרטון...';

  @override
  String get stageFinalizing => 'מסיים...';

  @override
  String get stageDone => 'מוכן לשמירה';

  @override
  String get stageFailed => 'נכשל';

  @override
  String get fullTranscodeTitle => 'נדרש עיבוד נוסף';

  @override
  String get fullTranscodeSubtitle =>
      'הסרטון דורש עיבוד נוסף כדי לעבוד טוב בטיקטוק ובאפליקציות אחרות. זה עשוי לקחת כמה דקות.';

  @override
  String progressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get downloadUnknownProgress => 'עובדים על זה...';

  @override
  String get bootstrapLoadingShort => 'מתחילים את LinkClip…';
}
