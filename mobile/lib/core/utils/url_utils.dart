/// Extract first http(s) URL from arbitrary shared text.
abstract final class UrlUtils {
  static final _re = RegExp(r"https?://[^\s<>\]\)\"']+", caseSensitive: false);

  static String? extractFirst(String input) {
    final m = _re.firstMatch(input.trim());
    return m?.group(0);
  }

  static String stripTrailingJunk(String url) {
    var u = url.trim();
    while (u.isNotEmpty) {
      final last = u[u.length - 1];
      if (".,);]\"'".contains(last)) {
        u = u.substring(0, u.length - 1);
        continue;
      }
      break;
    }
    return u;
  }

  static String normalizeServerBase(String raw) {
    var s = raw.trim();
    while (s.endsWith("/")) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return "";
    if (!s.startsWith("http://") && !s.startsWith("https://")) {
      s = "http://$s";
    }
    return s;
  }

  static bool looksLikeHttpUrl(String s) {
    final t = s.trim();
    return t.startsWith("http://") || t.startsWith("https://");
  }
}
