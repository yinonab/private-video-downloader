import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:image_picker/image_picker.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "selected_local_video.dart";

Future<String?> _copyByteStreamToTempFile({
  required Stream<List<int>> stream,
  required String suggestedBasename,
}) async {
  final dir = await getTemporaryDirectory();
  final safe =
      suggestedBasename.replaceAll(RegExp(r"[^\w.\-]+"), "_").trim().isEmpty
          ? "video.bin"
          : suggestedBasename.replaceAll(RegExp(r"[^\w.\-]+"), "_");
  final destPath =
      p.join(dir.path, "linkclip_local_pick_${DateTime.now().millisecondsSinceEpoch}_$safe");
  final dest = File(destPath);
  IOSink? sink;
  try {
    sink = dest.openWrite();
    await sink.addStream(stream);
    await sink.close();
    sink = null;
    return dest.path;
  } catch (_) {
    try {
      await sink?.close();
    } catch (_) {}
    try {
      if (await dest.exists()) await dest.delete();
    } catch (_) {}
    return null;
  }
}

Future<String?> _materializeXFile(XFile file) async {
  final rawPath = file.path.trim();
  if (rawPath.isNotEmpty &&
      !rawPath.startsWith("content:") &&
      await File(rawPath).exists()) {
    return rawPath;
  }
  final name =
      file.name.trim().isNotEmpty ? file.name.trim() : "${p.basename(rawPath)}.mp4";
  return _copyByteStreamToTempFile(stream: file.openRead(), suggestedBasename: name);
}

/// Picks a video from gallery / Google Photos style providers ([ImagePicker.pickVideo]).
Future<SelectedLocalVideo?> pickFromDeviceMedia() async {
  final picker = ImagePicker();
  final x = await picker.pickVideo(source: ImageSource.gallery);
  if (x == null) return null;

  final diskPath = await _materializeXFile(x);
  if (diskPath == null || diskPath.isEmpty) return null;

  int? sizeBytes;
  try {
    sizeBytes = await File(diskPath).length();
  } catch (_) {}

  final display =
      p.basename(diskPath).trim().isNotEmpty ? p.basename(diskPath) : x.name;

  return SelectedLocalVideo(
    pickKind: LocalVideoPickKind.mediaGallery,
    displayName: display.isNotEmpty ? display : "video.mp4",
    mimeType: null,
    sizeBytes: sizeBytes,
    filePath: diskPath,
    localPreviewPath: diskPath,
  );
}

/// File browser / SAF ([FilePicker]).
Future<SelectedLocalVideo?> pickFromFileBrowser() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: false,
    withData: false,
    withReadStream: true,
  );
  if (res == null || res.files.isEmpty) return null;
  final pf = res.files.single;

  final pickPath = pf.path?.trim();
  if (pickPath != null &&
      pickPath.isNotEmpty &&
      !pickPath.startsWith("content:") &&
      await File(pickPath).exists()) {
    int? sizeBytes = pf.size > 0 ? pf.size : null;
    if (sizeBytes == null) {
      try {
        sizeBytes = await File(pickPath).length();
      } catch (_) {}
    }
    final display =
        pf.name.trim().isNotEmpty ? pf.name.trim() : p.basename(pickPath);
    return SelectedLocalVideo(
      pickKind: LocalVideoPickKind.fileBrowser,
      displayName: display.isNotEmpty ? display : "video.mp4",
      mimeType: null,
      sizeBytes: sizeBytes,
      filePath: pickPath,
      localPreviewPath: pickPath,
    );
  }

  final stream = pf.readStream;
  if (stream != null) {
    final name =
        pf.name.trim().isNotEmpty ? pf.name.trim() : "picked_video.mp4";
    final diskPath = await _copyByteStreamToTempFile(
      stream: stream,
      suggestedBasename: name,
    );
    if (diskPath == null) return null;
    int? sizeBytes;
    try {
      sizeBytes = await File(diskPath).length();
    } catch (_) {}
    return SelectedLocalVideo(
      pickKind: LocalVideoPickKind.fileBrowser,
      displayName: name,
      mimeType: null,
      sizeBytes: sizeBytes,
      filePath: diskPath,
      localPreviewPath: diskPath,
    );
  }

  return null;
}

/// Ensures [selected] resolves to an absolute path readable by [File] and [ApiClient.uploadVideo].
Future<String?> materializeSelectedLocalVideoPath(SelectedLocalVideo selected) async {
  final fp = selected.filePath?.trim();
  if (fp != null &&
      fp.isNotEmpty &&
      !fp.startsWith("content:") &&
      await File(fp).exists()) {
    return fp;
  }
  return null;
}
