/// Local-only display filter for the Edits tab (by [LocalEditHistoryItem.savedAt]).
enum LocalEditHistoryTimeFilter {
  today,
  twoDays,
  threeDays,
  week,
  twoWeeks,
  month,
  unlimited,
}

DateTime? editHistoryFilterCutoff(LocalEditHistoryTimeFilter f) {
  final now = DateTime.now();
  switch (f) {
    case LocalEditHistoryTimeFilter.today:
      return DateTime(now.year, now.month, now.day);
    case LocalEditHistoryTimeFilter.twoDays:
      return now.subtract(const Duration(days: 2));
    case LocalEditHistoryTimeFilter.threeDays:
      return now.subtract(const Duration(days: 3));
    case LocalEditHistoryTimeFilter.week:
      return now.subtract(const Duration(days: 7));
    case LocalEditHistoryTimeFilter.twoWeeks:
      return now.subtract(const Duration(days: 14));
    case LocalEditHistoryTimeFilter.month:
      return now.subtract(const Duration(days: 30));
    case LocalEditHistoryTimeFilter.unlimited:
      return null;
  }
}
