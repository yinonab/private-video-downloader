import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../theme/linkclip_design_system.dart";
import "../widgets/linkclip_network_thumbnail.dart";
import "media_aspect.dart";
import "thumbnail_letterbox.dart";

/// How [LinkClipMediaThumbnail] sizes itself.
enum LinkClipMediaThumbnailLayout {
  /// Aspect-aware list/project tile (preferred for Home Downloads / Edits).
  tile,

  /// Fixed compact box (legacy). Prefer [tile].
  compact,
}

/// Image fit inside the tile frame.
enum LinkClipMediaThumbnailFit {
  /// Fill the aspect-correct frame; light edge crop. Default for list cards.
  cover,

  /// Letterbox — only for intentional large preview stages, not compact list tiles.
  containWithBackground,
}

/// Aspect-aware media thumbnail for Home list cards.
///
/// Handles platform thumbnails that already contain black letterbox bars by
/// detecting content bounds and sizing the tile to the **content** aspect.
class LinkClipMediaThumbnail extends StatefulWidget {
  const LinkClipMediaThumbnail({
    super.key,
    this.networkUrl,
    this.filePath,
    this.layout = LinkClipMediaThumbnailLayout.tile,
    this.fitStrategy = LinkClipMediaThumbnailFit.cover,
    this.aspectRatio,
    this.width = cardWidth,
    this.height = cardHeight,
    this.maxTileWidth = 148,
    this.maxTileHeight = 100,
    this.borderRadius,
    this.durationLabel,
    this.isAudio = false,
    this.isLoading = false,
    this.placeholderIcon,
    this.overlay,
    this.resolveImageAspect = true,
  }) : assert(
          networkUrl == null || filePath == null,
          "Provide either networkUrl or filePath, not both",
        );

  static const double cardWidth = 92;
  static const double cardHeight = 64;

  final String? networkUrl;
  final String? filePath;
  final LinkClipMediaThumbnailLayout layout;
  final LinkClipMediaThumbnailFit fitStrategy;
  final double? aspectRatio;
  final double width;
  final double height;
  final double maxTileWidth;
  final double maxTileHeight;
  final BorderRadius? borderRadius;
  final String? durationLabel;
  final bool isAudio;
  final bool isLoading;
  final IconData? placeholderIcon;
  final Widget? overlay;
  final bool resolveImageAspect;

  @override
  State<LinkClipMediaThumbnail> createState() => _LinkClipMediaThumbnailState();
}

class _LinkClipMediaThumbnailState extends State<LinkClipMediaThumbnail> {
  double? _resolvedAspect;
  ThumbnailContentBounds? _bounds;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  int _resolveGen = 0;

  @override
  void initState() {
    super.initState();
    _kickResolve();
  }

  @override
  void didUpdateWidget(LinkClipMediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.aspectRatio != widget.aspectRatio ||
        oldWidget.resolveImageAspect != widget.resolveImageAspect) {
      _resolvedAspect = null;
      _bounds = null;
      _kickResolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  ImageProvider? _provider() {
    final net = widget.networkUrl?.trim();
    final file = widget.filePath?.trim();
    if (net != null && net.isNotEmpty) {
      return NetworkImage(net, headers: LinkClipNetworkThumbnail.headersFor(net));
    }
    if (file != null && file.isNotEmpty) {
      return FileImage(File(file));
    }
    return null;
  }

  void _kickResolve() {
    _detach();
    if (widget.aspectRatio != null && widget.aspectRatio! > 0) {
      _resolvedAspect = widget.aspectRatio;
      return;
    }
    if (!widget.resolveImageAspect) return;

    final provider = _provider();
    if (provider == null) return;

    final gen = ++_resolveGen;
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) async {
        stream.removeListener(listener);
        if (identical(_listener, listener)) {
          _listener = null;
          _stream = null;
        }
        if (!mounted || gen != _resolveGen) return;

        final w = info.image.width;
        final h = info.image.height;
        if (w <= 0 || h <= 0) return;

        ThumbnailContentBounds? bounds;
        try {
          bounds = await analyzeUiImageLetterbox(info.image);
        } catch (_) {
          bounds = null;
        }
        if (!mounted || gen != _resolveGen) return;

        final aspect = bounds?.displayAspect ?? (w / h);
        final mode = MediaAspect.kindOf(aspect).name;
        debugLogThumbnailAspect(
          pathType: widget.networkUrl != null ? "source_remote" : "source_file",
          width: bounds?.contentWidth ?? w,
          height: bounds?.contentHeight ?? h,
          aspect: aspect,
          mode: mode,
          letterboxed: bounds?.hasSignificantBars,
        );

        setState(() {
          _bounds = bounds != null && bounds.hasSignificantBars ? bounds : null;
          _resolvedAspect = aspect;
        });
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (identical(_listener, listener)) {
          _listener = null;
          _stream = null;
        }
        if (kDebugMode) {
          debugPrint("thumbnail aspect: resolve failed pathType=source");
        }
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  double? get _knownAspect {
    final explicit = widget.aspectRatio;
    if (explicit != null && explicit > 0) {
      // Explicit media w/h — trust it; still allow letterbox crop for display.
      return _bounds?.hasSignificantBars == true
          ? _bounds!.displayAspect
          : explicit;
    }
    if (_resolvedAspect != null && _resolvedAspect! > 0) return _resolvedAspect;
    return null;
  }

  /// While resolving: landscape-leaning placeholder so wide media is not stuck
  /// in a tall portrait slot before decode finishes.
  double get _effectiveAspect => _knownAspect ?? (16 / 9);

  BoxFit get _boxFit {
    if (widget.fitStrategy == LinkClipMediaThumbnailFit.containWithBackground) {
      return BoxFit.contain;
    }
    return BoxFit.cover;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(LcRadius.medium);
    final aspect = _effectiveAspect;
    final boxFit = _boxFit;

    final size = widget.layout == LinkClipMediaThumbnailLayout.tile
        ? MediaAspect.tileSize(
            aspect: aspect,
            maxWidth: widget.maxTileWidth,
            maxHeight: widget.maxTileHeight,
          )
        : (width: widget.width, height: widget.height);

    final decodeW = (size.width * dpr).round().clamp(96, 1200);

    Widget? image;
    final net = widget.networkUrl?.trim();
    final file = widget.filePath?.trim();
    final bounds = _bounds;

    if (net != null && net.isNotEmpty) {
      image = bounds != null
          ? _LetterboxCroppedNetworkImage(
              url: net,
              bounds: bounds,
              cacheWidth: decodeW,
              errorBuilder: (_, __, ___) => _placeholder(scheme, size.height),
            )
          : LinkClipNetworkThumbnail(
              imageUrl: net,
              fit: boxFit,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: decodeW,
              errorBuilder: (_, __, ___) => _placeholder(scheme, size.height),
              loadingBuilder: (context, child, prog) {
                if (prog == null) return child;
                return _placeholder(scheme, size.height, loading: true);
              },
            );
    } else if (file != null && file.isNotEmpty) {
      image = bounds != null
          ? _LetterboxCroppedFileImage(
              path: file,
              bounds: bounds,
              cacheWidth: decodeW,
              errorBuilder: (_, __, ___) => _placeholder(scheme, size.height),
            )
          : Image.file(
              File(file),
              fit: boxFit,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              cacheWidth: decodeW,
              errorBuilder: (_, __, ___) => _placeholder(scheme, size.height),
            );
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark ? 0.78 : 0.62,
              ),
            ),
            if (image != null)
              image
            else if (widget.isLoading)
              _placeholder(scheme, size.height, loading: true)
            else
              _placeholder(scheme, size.height),
            if (widget.overlay != null) widget.overlay!,
            if (widget.durationLabel != null &&
                widget.durationLabel!.trim().isNotEmpty)
              PositionedDirectional(
                end: 6,
                bottom: 6,
                child: _DurationBadge(label: widget.durationLabel!.trim()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme, double tileH, {bool loading = false}) {
    if (loading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary.withValues(alpha: 0.8),
          ),
        ),
      );
    }
    final icon = widget.placeholderIcon ??
        (widget.isAudio ? LucideIcons.audioLines : LucideIcons.video);
    return Center(
      child: Icon(
        icon,
        size: (tileH * 0.36).clamp(22.0, 36.0),
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

/// Paints only the non-letterboxed content region, scaled with cover.
class _LetterboxCroppedNetworkImage extends StatelessWidget {
  const _LetterboxCroppedNetworkImage({
    required this.url,
    required this.bounds,
    required this.cacheWidth,
    this.errorBuilder,
  });

  final String url;
  final ThumbnailContentBounds bounds;
  final int cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return _LetterboxCroppedPaint(
      bounds: bounds,
      image: NetworkImage(url, headers: LinkClipNetworkThumbnail.headersFor(url)),
      cacheWidth: cacheWidth,
      errorBuilder: errorBuilder,
    );
  }
}

class _LetterboxCroppedFileImage extends StatelessWidget {
  const _LetterboxCroppedFileImage({
    required this.path,
    required this.bounds,
    required this.cacheWidth,
    this.errorBuilder,
  });

  final String path;
  final ThumbnailContentBounds bounds;
  final int cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return _LetterboxCroppedPaint(
      bounds: bounds,
      image: FileImage(File(path)),
      cacheWidth: cacheWidth,
      errorBuilder: errorBuilder,
    );
  }
}

class _LetterboxCroppedPaint extends StatelessWidget {
  const _LetterboxCroppedPaint({
    required this.bounds,
    required this.image,
    required this.cacheWidth,
    this.errorBuilder,
  });

  final ThumbnailContentBounds bounds;
  final ImageProvider image;
  final int cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final iw = bounds.imageWidth.toDouble();
    final ih = bounds.imageHeight.toDouble();
    final cw = bounds.contentWidth.toDouble();
    final ch = bounds.contentHeight.toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final tw = constraints.maxWidth;
        final th = constraints.maxHeight;
        // Cover: scale so content fills the tile.
        final scale = (tw / cw > th / ch) ? tw / cw : th / ch;
        final drawnW = iw * scale;
        final drawnH = ih * scale;
        final dx = -bounds.left * scale + (tw - cw * scale) / 2;
        final dy = -bounds.top * scale + (th - ch * scale) / 2;

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: dx,
                top: dy,
                width: drawnW,
                height: drawnH,
                child: Image(
                  image: ResizeImage(image, width: cacheWidth),
                  fit: BoxFit.fill,
                  width: drawnW,
                  height: drawnH,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: errorBuilder,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
