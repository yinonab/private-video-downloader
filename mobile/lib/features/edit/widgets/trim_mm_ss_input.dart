import "dart:math" as math;

import "package:flutter/services.dart";

/// Strips everything except ASCII digits.
String trimTimeDigitsOnly(String raw) {
  final sb = StringBuffer();
  for (final c in raw.runes) {
    if (c >= 0x30 && c <= 0x39) sb.writeCharCode(c);
  }
  return sb.toString();
}

/// Digit-buffer → MM:SS preview string (typing without `:`).
///
/// `1→00:01`, `12→00:12`, `0012→00:12`, `123→01:23`, `1234→12:34`.
/// Seconds are always the last two digits (`00`–`59`); earlier digits are minutes.
/// For ≤2 digits the whole sequence is interpreted as seconds (capped at 59).
String formatMmSsDisplayFromDigits(String digitsRaw, {int maxDigits = 8}) {
  var d = trimTimeDigitsOnly(digitsRaw);
  if (d.length > maxDigits) d = d.substring(0, maxDigits);

  if (d.isEmpty) return "00:00";

  if (d.length <= 2) {
    final secs = math.min(int.parse(d), 59);
    return "00:${secs.toString().padLeft(2, '0')}";
  }

  final ssDigits = d.substring(d.length - 2);
  final ss = math.min(int.parse(ssDigits), 59);
  final mmDigits = d.substring(0, d.length - 2);
  final mm = math.max(int.tryParse(mmDigits) ?? 0, 0);
  return "${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}";
}

/// Seconds from digit-buffer rules (`SS` capped 0–59). Caller clamps total to duration.
double secondsFromMmSsDigits(String textOrDigits, {int maxDigits = 8}) {
  var d = trimTimeDigitsOnly(textOrDigits);
  if (d.length > maxDigits) d = d.substring(0, maxDigits);

  if (d.isEmpty) return 0;

  if (d.length <= 2) {
    return math.min(int.parse(d), 59).toDouble();
  }

  final ssDigits = d.substring(d.length - 2);
  final ss = math.min(int.parse(ssDigits), 59);
  final mmDigits = d.substring(0, d.length - 2);
  final mm = math.max(int.tryParse(mmDigits) ?? 0, 0);
  return mm * 60 + ss.toDouble();
}

/// Digit buffer that round-trips with [formatMmSsDisplayFromDigits] + [secondsFromMmSsDigits].
String digitBufferFromWholeSeconds(int t) {
  final sec = math.max(0, t);
  final mm = sec ~/ 60;
  final ss = sec % 60;
  if (mm <= 0) return ss.toString();
  return "$mm${ss.toString().padLeft(2, '0')}";
}

/// Digits-only, max length — raw buffer shown in the editor while typing.
List<TextInputFormatter> trimRawDigitsOnlyFormatters({int maxDigits = 8}) => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(maxDigits),
    ];

/// @deprecated Prefer [trimRawDigitsOnlyFormatters] — sheet shows raw digits + separate MM:SS preview.
class TrimMmSsDigitInputFormatter extends TextInputFormatter {
  TrimMmSsDigitInputFormatter({this.maxDigits = 8});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = trimTimeDigitsOnly(newValue.text);
    if (d.length > maxDigits) d = d.substring(0, maxDigits);

    final display = formatMmSsDisplayFromDigits(d, maxDigits: maxDigits);
    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
      composing: TextRange.empty,
    );
  }
}
