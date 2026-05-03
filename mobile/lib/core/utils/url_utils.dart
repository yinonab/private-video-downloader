/// Extract first http(s) URL from arbitrary shared text.
abstract final class UrlUtils {
  /// Pulls the first `http://` or `https://` substring and trims trailing junk.
  static String? extractFirst(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    final lower = s.toLowerCase();
    final iHttp = lower.indexOf("http://");
    final iHttps = lower.indexOf("https://");

    final start = _earliestNonNegative(iHttp, iHttps);
    if (start < 0) return null;

    var end = start;
    while (end < s.length) {
      final code = s.codeUnitAt(end);
      if (code == 0x20 || code == 0x09 || code == 0x0a || code == 0x0d) break;
      end++;
    }

    return stripTrailingJunk(s.substring(start, end));
  }

  static int _earliestNonNegative(int a, int b) {
    if (a >= 0 && b >= 0) return a < b ? a : b;
    if (a >= 0) return a;
    if (b >= 0) return b;
    return -1;
  }

  static String stripTrailingJunk(String url) {
    var u = url.trim();
    while (u.isNotEmpty) {
      final last = u[u.length - 1];
      if (".,);]}\"'«»".contains(last)) {
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

    final lower = s.toLowerCase();
    if (!lower.startsWith("http://") && !lower.startsWith("https://")) {
      s = "http://$s";
    }

    final uri = Uri.tryParse(s);
    if (uri != null && uri.scheme != "http" && uri.scheme != "https") {
      return "";
    }
    return s;
  }

  static bool looksLikeHttpUrl(String input) {
    final t = stripTrailingJunk(input.trim());
    if (t.isEmpty) return false;
    final lower = t.toLowerCase();
    if (!lower.startsWith("http://") && !lower.startsWith("https://")) {
      return false;
    }
    final uri = Uri.tryParse(t);
    return uri != null && (uri.scheme == "http" || uri.scheme == "https");
  }
}
