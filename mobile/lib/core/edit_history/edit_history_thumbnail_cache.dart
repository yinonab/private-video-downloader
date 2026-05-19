import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:video_thumbnail/video_thumbnail.dart";

/// One JPEG frame from [videoPath], written under app support (`edit_thumbnails/`).
/// Does not load the whole video into Dart memory.
Future<String?> generateEditHistoryThumbnailFile({
  required String videoPath,
  required String editJobId,
}) async {
  final vf = File(videoPath.trim());
  if (!await vf.exists()) return null;

  final id = editJobId.trim();
  if (id.isEmpty) return null;

  final support = await getApplicationSupportDirectory();
  final dir = Directory(p.join(support.path, "edit_thumbnails"));
  await dir.create(recursive: true);
  final targetPath = p.join(dir.path, "$id.jpg");
  final existing = File(targetPath);
  if (await existing.exists() && await existing.length() > 0) {
    return targetPath;
  }

  try {
    final tmp = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 256,
      quality: 75,
      timeMs: 900,
    );
    if (tmp == null) return null;
    final tmpFile = File(tmp);
    if (!await tmpFile.exists()) return null;
    await tmpFile.copy(targetPath);
    try {
      await tmpFile.delete();
    } catch (_) {}
    return targetPath;
  } catch (_) {
    try {
      if (await existing.exists()) await existing.delete();
    } catch (_) {}
    return null;
  }
}
