/// Lightweight HTML entity decode for API titles/thumbnail URLs (numeric + common named).
String decodeBasicHtmlEntities(String input) {
  String charFromCodePoint(int code) {
    if (code < 0 || code > 0x10ffff) return '';
    if (code >= 0xd800 && code <= 0xdfff) return '';
    if (code <= 0xffff) return String.fromCharCode(code);
    final base = code - 0x10000;
    final hi = 0xd800 | (base >> 10);
    final lo = 0xdc00 | (base & 0x3ff);
    return String.fromCharCodes([hi, lo]);
  }

  var s = input;
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]{1,6});?', caseSensitive: false), (m) {
    final hex = m[1];
    if (hex == null) return m[0]!;
    final code = int.tryParse(hex, radix: 16);
    if (code == null) return m[0]!;
    final ch = charFromCodePoint(code);
    return ch.isEmpty ? m[0]! : ch;
  });
  s = s.replaceAllMapped(RegExp(r'&#(\d{1,7});?'), (m) {
    final dec = m[1];
    if (dec == null) return m[0]!;
    final code = int.tryParse(dec);
    if (code == null) return m[0]!;
    final ch = charFromCodePoint(code);
    return ch.isEmpty ? m[0]! : ch;
  });
  return s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

/// Decode thumbnail URL query strings that still contain `&amp;` after JSON/HTML transit.
String? decodeThumbnailUrl(String? raw) {
  if (raw == null) return null;
  final t = decodeBasicHtmlEntities(raw.trim());
  if (t.isEmpty) return null;
  final u = Uri.tryParse(t);
  return u == null || !u.hasScheme ? t : u.toString();
}
