import '../utils/html_entities.dart';

class AvailableQuality {
  AvailableQuality({
    required this.id,
    required this.label,
    required this.available,
    this.reason,
  });

  factory AvailableQuality.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    return AvailableQuality(
      id: "${m["id"] ?? ""}",
      label: "${m["label"] ?? ""}",
      available: m["available"] == true,
      reason: m["reason"]?.toString(),
    );
  }

  final String id;
  final String label;
  final bool available;
  final String? reason;
}

class FormatOption {
  FormatOption({
    required this.label,
    required this.value,
    required this.type,
    this.available = true,
    this.reason,
  });

  factory FormatOption.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final rawVal = "${m["value"] ?? ""}";
    return FormatOption(
      label: "${m["label"] ?? ""}",
      value: rawVal == "audio_mp3" ? "audio" : rawVal,
      type: "${m["type"] ?? ""}",
      available: m["available"] != false,
      reason: m["reason"]?.toString(),
    );
  }

  static List<FormatOption> platformDefaults() => [
        FormatOption(label: "Best MP4", value: "best", type: "video"),
        FormatOption(label: "TikTok-ready MP4", value: "tiktok_ready", type: "video"),
        FormatOption(label: "1080p MP4", value: "1080p", type: "video"),
        FormatOption(label: "720p MP4", value: "720p", type: "video"),
        FormatOption(label: "480p MP4", value: "480p", type: "video"),
        FormatOption(label: "Audio MP3", value: "audio", type: "audio"),
      ];

  static const _canonicalOrder = ["best", "tiktok_ready", "1080p", "720p", "480p", "audio"];

  static List<FormatOption> fromAvailableQualities(List<AvailableQuality> qualities) {
    final byId = <String, AvailableQuality>{};
    for (final q in qualities) {
      final id = q.id == "audio_mp3" ? "audio" : q.id;
      byId[id] = AvailableQuality(id: id, label: q.label, available: q.available, reason: q.reason);
    }
    final out = <FormatOption>[];
    for (final id in _canonicalOrder) {
      final q = byId[id];
      if (q == null) continue;
      out.add(
        FormatOption(
          label: q.label.isEmpty ? _defaultLabel(id) : q.label,
          value: id,
          type: id == "audio" ? "audio" : "video",
          available: q.available,
          reason: q.reason,
        ),
      );
    }
    return out.isEmpty ? platformDefaults() : out;
  }

  static List<FormatOption> mergeLegacyFormats(List<FormatOption> legacy) {
    final defaults = platformDefaults();
    final by = <String, FormatOption>{};
    for (final x in legacy) {
      final k = x.value == "audio_mp3" ? "audio" : x.value;
      by[k] = FormatOption(
        label: x.label,
        value: k,
        type: x.type,
        available: x.available,
        reason: x.reason,
      );
    }
    return [
      for (final d in defaults)
        () {
          final hit = by[d.value];
          if (hit != null) {
            return FormatOption(
              label: hit.label.isEmpty ? d.label : hit.label,
              value: d.value,
              type: d.type,
              available: hit.available,
              reason: hit.reason,
            );
          }
          return d;
        }(),
    ];
  }

  static String _defaultLabel(String id) {
    switch (id) {
      case "best":
        return "Best MP4";
      case "1080p":
        return "1080p MP4";
      case "720p":
        return "720p MP4";
      case "480p":
        return "480p MP4";
      case "audio":
        return "Audio MP3";
      case "tiktok_ready":
        return "TikTok-ready MP4";
      default:
        return id;
    }
  }

  static bool isAudioFormat(FormatOption f) =>
      f.type == "audio" || f.value == "audio" || f.value == "audio_mp3";

  static List<int> indicesForVideo(List<FormatOption> formats) => [
        for (var i = 0; i < formats.length; i++)
          if (!isAudioFormat(formats[i])) i,
      ];

  static List<int> indicesForAudio(List<FormatOption> formats) => [
        for (var i = 0; i < formats.length; i++)
          if (isAudioFormat(formats[i])) i,
      ];

  static int pickDefaultFormatIndex(List<FormatOption> formats) {
    bool matchesId(FormatOption f, String id) {
      final v = f.value;
      if (id == "audio") return v == "audio" || v == "audio_mp3";
      return v == id;
    }

    const prefs = ["best", "720p", "480p", "audio", "1080p"];
    for (final p in prefs) {
      final i = formats.indexWhere((f) => matchesId(f, p) && f.available);
      if (i >= 0) return i;
    }
    final any = formats.indexWhere((f) => f.available);
    return any >= 0 ? any : 0;
  }

  static int clampSelectableIndex(List<FormatOption> formats, int current) {
    if (formats.isEmpty) return 0;
    final i = current.clamp(0, formats.length - 1);
    if (formats[i].available) return i;
    return pickDefaultFormatIndex(formats);
  }

  final String label;
  final String value;
  final String type;
  final bool available;
  final String? reason;
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

    List<AvailableQuality>? aqList;
    if (m["availableQualities"] is List) {
      aqList = [];
      for (final e in m["availableQualities"] as List) {
        if (e is Map) aqList.add(AvailableQuality.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    late final List<FormatOption> merged;
    if (aqList != null && aqList.isNotEmpty) {
      merged = FormatOption.fromAvailableQualities(aqList);
    } else {
      final fmts = <FormatOption>[];
      if (m["availableFormats"] is List) {
        for (final e in m["availableFormats"] as List) {
          if (e is Map) fmts.add(FormatOption.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      merged = fmts.isEmpty ? FormatOption.platformDefaults() : FormatOption.mergeLegacyFormats(fmts);
    }

    final dur = (m["durationSec"] is num)
        ? (m["durationSec"] as num).round()
        : int.tryParse("${m["durationSec"] ?? ""}");

    return AnalyzeResponse(
      url: "${m["url"] ?? ""}",
      title: () {
        final raw = "${m["title"] ?? ""}".trim();
        final decoded = decodeBasicHtmlEntities(raw);
        return decoded.isEmpty ? "ללא כותרת" : decoded;
      }(),
      platform: "${m["platform"] ?? ""}".trim().isEmpty ? "לא ידוע" : "${m["platform"]}",
      extractor: m["extractor"]?.toString(),
      durationSec: dur,
      thumbnail: decodeThumbnailUrl(m["thumbnail"]?.toString()),
      availableFormats: merged,
    );
  }

  int pickDefaultFormatIndex() => FormatOption.pickDefaultFormatIndex(availableFormats);

  final String url;
  final String title;
  final String platform;
  final String? extractor;
  final int? durationSec;
  final String? thumbnail;
  final List<FormatOption> availableFormats;
}
