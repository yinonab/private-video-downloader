import "package:dio/dio.dart";

/// Normalized backend error plus Hebrew-friendly UX copy.
class ApiError implements Exception {
  ApiError({
    required this.code,
    required this.message,
    this.details,
    this.hebrewSummary,
    this.httpStatus,
    this.existingJobId,
  });

  factory ApiError.fromUnknown(Object error) {
    if (error is ApiError) return error;
    if (error is DioException) return ApiError.fromDio(error);
    return ApiError(code: "UNKNOWN", message: "$error", hebrewSummary: "אירעה שגיאה לא צפויה");
  }

  factory ApiError.fromDio(DioException e) {
    final raw = _parseBody(e.response?.data);
    final msg = raw.$1 == "NETWORK" && raw.$2 == "network" ? _dioMessageFallback(e) : raw.$2;
    final code = raw.$1;
    final heb = raw.$3 ?? hebrewForCode(code, e.response?.statusCode);
    return ApiError(
      code: code,
      message: msg,
      details: raw.$4,
      existingJobId: raw.$5,
      httpStatus: e.response?.statusCode,
      hebrewSummary: heb,
    );
  }

  static String _dioMessageFallback(DioException e) {
    final m = (e.message ?? "").trim();
    return m.isEmpty ? "$e" : m;
  }

  final String code;
  final String message;
  final String? details;
  final String? hebrewSummary;
  final int? httpStatus;
  final String? existingJobId;

  String get localized => hebrewSummary ?? message;

  /// Returns (code, message, hebrew?, details?, existingJobId?)
  static (String, String, String?, String?, String?) _parseBody(Object? body) {
    if (body is Map) {
      final err = body["error"];
      if (err is Map) {
        final map = Map<String, dynamic>.from(err);
        final code = "${map["code"] ?? map["cod"] ?? "ERROR"}".trim().isEmpty ? "ERROR" : "${map["code"]}";
        final message = "${map["message"] ?? ""}";
        final details = map["details"] == null ? null : "${map["details"]}";
        final existingJobId = map["existingJobId"] != null ? "${map["existingJobId"]}" : null;
        return (code, message.isEmpty ? "שגיאה" : message, hebrewForCode(code, null), details, existingJobId);
      }
    }
    if (body is String && body.isNotEmpty) {
      return ("ERROR", body, null, null, null);
    }
    return ("NETWORK", "network", null, null, null);
  }

  static String hebrewForCode(String code, int? http) {
    switch (code) {
      case "INVALID_URL":
        return "הקישור לא תקין";
      case "DEVICE_NOT_REGISTERED":
        return "המכשיר לא רשום";
      case "DEVICE_BLOCKED":
        return "המכשיר חסום";
      case "RATE_LIMITED":
        return "הגעת למגבלה היומית";
      case "INVITE_CODE_INVALID":
      case "INVITE_CODE_EXPIRED":
        return "קוד הזמנה לא תקף";
      case "ANALYZE_FAILED":
        return "לא ניתן לנתח את הקישור";
      case "JOB_NOT_FOUND":
        return "ההורדה לא נמצאה";
      case "DOWNLOAD_FAILED":
        return "ההורדה נכשלה — ניתן לנסות שוב";
      case "CONFLICT":
        return "הורדה אחרת כבר מתבצעת במכשיר";
      case "FILE_NOT_FOUND":
        return "הקובץ לא נמצא";
      case "UNAUTHORIZED":
        return "אין הרשאה לפעולה";
      case "BAD_REQUEST":
        return "בקשה לא תקינה";
      case "UNSUPPORTED_QUALITY":
        return "האיכות שנבחרה אינה נתמכת. נסה לבחור איכות אחרת.";
      case "LINKCLIP_ERR_THREADS_UNSUPPORTED":
        return "קישורי Threads עדיין לא נתמכים להורדה. נסה קישור מאינסטגרם, טיקטוק, פייסבוק או יוטיוב.";
      case "LINKCLIP_ERR_PLATFORM_UNSUPPORTED":
        return "קישור זה עדיין לא נתמך להורדה. נסה קישור מאינסטגרם, טיקטוק, פייסבוק או יוטיוב.";
      case "LINKCLIP_ERR_ANALYZE_METADATA_UNAVAILABLE":
        return "לא ניתן לטעון אפשרויות פורמט לווידאו. ייתכן שהקישור מוגבל או לא זמין זמנית.";
      case "DRM_PROTECTED":
        return "לא ניתן להוריד את הקישור הזה כי התוכן מוגן בזכויות/DRM.";
      case "EDIT_OUTPUT_UNAVAILABLE":
        return "הסרטון הערוך כבר לא זמין בשרת ולא נמצא במכשיר.";
      case "FACEBOOK_EXTRACT_FAILED":
        return "לא הצלחנו לקרוא את הסרטון מפייסבוק כרגע. ייתכן שהקישור דורש גישה מיוחדת או שפייסבוק חסמה את הגישה אליו. נסה קישור אחר או נסה שוב מאוחר יותר.";
      case "EDIT_JOB_NOT_FOUND":
        return "משימת העריכה לא נמצאה.";
      case "EDIT_INVALID_SOURCE":
        return "לא ניתן לערוך את המקור הזה.";
      case "EDIT_FAILED":
        return "העריכה נכשלה.";
      case "UPLOAD_FILE_TOO_LARGE":
        return "הסרטון גדול מדי לעריכה כרגע. אפשר להעלות סרטונים עד 175MB.";
      case "UPLOAD_VIDEO_TOO_LONG":
        return "הסרטון ארוך מדי לעריכה כרגע. אפשר להעלות קליפים עד 7 דקות.";
      case "UPLOAD_UNSUPPORTED_TYPE":
        return "סוג הקובץ לא נתמך. נסה סרטון MP4.";
      case "UNSUPPORTED_SPEED_FACTOR":
        return "אפשרות המהירות הזו לא נתמכת.";
      case "UNSUPPORTED_FORMAT_MODE":
        return "מצב הפורמט הזה לא נתמך.";
      case "UNSUPPORTED_ROTATION":
        return "אפשרות הסיבוב הזו לא נתמכת.";
      case "UPLOAD_INVALID_VIDEO":
        return "לא הצלחנו לקרוא את הסרטון הזה. נסה סרטון אחר.";
      case "UPLOAD_FAILED":
        return "לא הצלחנו להעלות את הסרטון. נסה שוב.";
      case "UPLOAD_NOT_FOUND":
      case "EDIT_UPLOAD_NOT_FOUND":
      case "EDIT_SOURCE_FILE_MISSING":
        return "הסרטון שהעלית כבר לא זמין. בחר אותו מחדש.";
      case "EDIT_UPLOAD_NOT_READY":
        return "הסרטון עדיין לא מוכן לעריכה. נסה שוב בעוד רגע.";
      case "EDIT_SOURCE_REQUIRED":
        return "לא נבחר מקור לעריכה.";
      case "EDIT_MULTIPLE_SOURCES":
        return "נבחרו יותר מדי מקורות לעריכה. נסה שוב.";
      case "UNSUPPORTED_CAPTIONS_MODE":
      case "UNSUPPORTED_CAPTIONS_LANGUAGE":
        return "אפשרות הכתוביות הזו לא נתמכת.";
      case "UNSUPPORTED_CAPTIONS_STYLE":
        return "סגנון הכתוביות הזה לא נתמך.";
      case "UNSUPPORTED_CAPTIONS_POSITION":
      case "UNSUPPORTED_CAPTIONS_POSITION_OFFSET":
        return "מיקום הכתוביות הזה לא נתמך.";
      case "UNSUPPORTED_CAPTIONS_FONT_SIZE":
        return "גודל הכתוביות הזה לא נתמך.";
      case "UNSUPPORTED_CAPTIONS_COLOR":
        return "צבע הכתוביות הזה לא נתמך.";
      case "CAPTIONS_TRANSCRIPTION_UNAVAILABLE":
        return "כתוביות אינן זמינות כרגע.";
      case "CAPTIONS_GENERATION_FAILED":
        return "לא ניתן ליצור כתוביות לסרטון הזה.";
      case "NETWORK":
        return http != null ? "שגיאת רשת (קוד $http)" : "שגיאת רשת";
      default:
        if (http != null) return "שגיאת שרת ($http)";
        return "שגיאה";
    }
  }

  @override
  String toString() => code == "NETWORK" ? message : localized;
}
