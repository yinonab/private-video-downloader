/// Maps raw worker/backend messages to readable Hebrew for the main UI.
String formatDownloadJobError(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  if (t.contains("Requested format is not available")) {
    return "האיכות שנבחרה לא זמינה לסרטון הזה. נסה איכות אחרת או Best MP4.";
  }
  return t;
}
