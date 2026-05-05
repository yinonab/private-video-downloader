/// Compact human-readable sizes for progress labels (en/he locale-neutral units).
String formatBytesUi(int bytes) {
  if (bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  if (i == 0) return "${v.round()} ${units[i]}";
  return "${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${units[i]}";
}
