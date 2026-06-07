/// MIME type from a local media basename (best-effort for share/open).
String mimeTypeForMediaPath(String path) {
  final lower = path.trim().toLowerCase();
  if (lower.endsWith(".mp3")) return "audio/mpeg";
  if (lower.endsWith(".m4a")) return "audio/mp4";
  if (lower.endsWith(".wav")) return "audio/wav";
  if (lower.endsWith(".mp4")) return "video/mp4";
  return "application/octet-stream";
}

bool pathLooksLikeAudio(String path) {
  final lower = path.trim().toLowerCase();
  return lower.endsWith(".mp3") ||
      lower.endsWith(".m4a") ||
      lower.endsWith(".wav") ||
      lower.endsWith(".aac");
}
