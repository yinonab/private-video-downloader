// One-off helper: pad edit-video.png into a safe adaptive-icon source.
// Artwork is centered at ~76% of the canvas (transparent margin).
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const sourcePath = 'assets/edit-video.png';
  const outDir = 'assets/app_icon';
  const outPath = '$outDir/linkclip_icon_padded.png';
  const canvasSize = 1024;
  // Artwork occupies ~76% of canvas → ~12% transparent margin each side.
  const artworkScale = 0.76;

  final bytes = File(sourcePath).readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('Failed to decode $sourcePath');
    exit(1);
  }

  final target = (canvasSize * artworkScale).round();
  final resized = img.copyResize(
    src,
    width: target,
    height: target,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  // Transparent background.
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final ox = ((canvasSize - resized.width) / 2).round();
  final oy = ((canvasSize - resized.height) / 2).round();
  img.compositeImage(canvas, resized, dstX: ox, dstY: oy);

  Directory(outDir).createSync(recursive: true);
  File(outPath).writeAsBytesSync(img.encodePng(canvas));
  print('Wrote $outPath (${canvasSize}x$canvasSize, artwork ${artworkScale * 100}%)');
}
