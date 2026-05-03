class FormatOption {
  FormatOption({required this.label, required this.value, required this.type});

  factory FormatOption.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    return FormatOption(
      label: "${m["label"] ?? ""}",
      value: "${m["value"] ?? ""}",
      type: "${m["type"] ?? ""}",
    );
  }

  /// Safe defaults if backend misses list.
  static List<FormatOption> platformDefaults() => [
        FormatOption(label: "Best MP4", value: "best", type: "video"),
        FormatOption(label: "1080p MP4", value: "1080p", type: "video"),
        FormatOption(label: "720p MP4", value: "720p", type: "video"),
        FormatOption(label: "Audio MP3", value: "audio_mp3", type: "audio"),
      ];

  final String label;
  final String value;
  final String type;
}

class AnalyzeResponse {
  AnalyzeResponse({
    required this.url,
    required this.title,
    required this.platform,
    this.extractor,
    this.durationSec,
    this.thumbnail,
    required this.availableFormats,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final fmts = <FormatOption>[];
    if (m["availableFormats"] is List) {
      for (final e in (m["availableFormats"] as List)) {
        if (e is Map) fmts.add(FormatOption.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final merged = fmts.isEmpty ? FormatOption.platformDefaults() : fmts;
    final dur = (m["durationSec"] is num)
        ? (m["durationSec"] as num).round()
        : int.tryParse("${m["durationSec"] ?? ""}");

    return AnalyzeResponse(
      url: "${m["url"] ?? ""}",
      title: "${m["title"] ?? ""}".trim().isEmpty ? "ללא כותרת" : "${m["title"]}",
      platform: "${m["platform"] ?? ""}".trim().isEmpty ? "לא ידוע" : "${m["platform"]}",
      extractor: m["extractor"]?.toString(),
      durationSec: dur,
      thumbnail: m["thumbnail"]?.toString(),
      availableFormats: merged,
    );
  }

  final String url;
  final String title;
  final String platform;
  final String? extractor;
  final int? durationSec;
  final String? thumbnail;
  final List<FormatOption> availableFormats;
}
