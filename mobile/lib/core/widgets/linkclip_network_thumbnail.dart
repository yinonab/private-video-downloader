import 'package:flutter/material.dart';

/// Some CDNs (notably Facebook `*.fbcdn.net` / `scontent*`) reject requests without a browser Referer.
class LinkClipNetworkThumbnail extends StatelessWidget {
  const LinkClipNetworkThumbnail({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String imageUrl;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  static Map<String, String>? _headers(String url) {
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
      headers: _headers(imageUrl),
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
