import 'package:flutter/material.dart';

/// Some CDNs (notably Facebook `*.fbcdn.net` / `scontent*`) reject requests without a browser Referer.
class LinkClipNetworkThumbnail extends StatelessWidget {
  const LinkClipNetworkThumbnail({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  /// Headers for Facebook CDN thumbs (also used when resolving image aspect).
  static Map<String, String>? headersFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('fbcdn.net') || host.contains('facebook.com')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.facebook.com/',
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      // Prefer leaving cacheHeight null when cacheWidth is set so decode
      // preserves aspect ratio (both set can squeeze on some engines).
      cacheHeight: cacheWidth != null ? null : cacheHeight,
      alignment: alignment,
      filterQuality: filterQuality,
      headers: headersFor(imageUrl),
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
