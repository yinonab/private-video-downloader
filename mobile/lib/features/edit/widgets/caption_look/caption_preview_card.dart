import "package:flutter/material.dart";

import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";
import "../edit_captions_preview_overlay.dart";

/// Cinematic animated caption stage for the look editor (V3.4F).
class CaptionPreviewCard extends StatefulWidget {
  const CaptionPreviewCard({
    super.key,
    required this.l10n,
    required this.snapshot,
    this.showSafeGuides = false,
    this.accentColor,
    this.onFullscreen,
  });

  final AppLocalizations l10n;
  final CaptionLookSnapshot snapshot;
  final bool showSafeGuides;
  final Color? accentColor;
  final VoidCallback? onFullscreen;

  static const double stageHeight = 136;

  @override
  State<CaptionPreviewCard> createState() => _CaptionPreviewCardState();
}

class _CaptionPreviewCardState extends State<CaptionPreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Object? _lastStyleToken;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _lastStyleToken = _styleToken(widget.snapshot);
  }

  @override
  void didUpdateWidget(CaptionPreviewCard old) {
    super.didUpdateWidget(old);
    final token = _styleToken(widget.snapshot);
    if (token != _lastStyleToken) {
      _lastStyleToken = token;
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Object _styleToken(CaptionLookSnapshot s) => (
        s.style,
        s.fontSize,
        s.fontFamily,
        s.color,
        s.wordHighlight,
        s.normalTextColor,
        s.activeTextColor,
        s.boxColor,
        s.boxShape,
        s.outlineEnabled,
        s.outlineColor,
        s.outlineWidth,
        s.offsetX,
        s.offsetY,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? scheme.primary;
    final s = widget.snapshot;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        elevation: isDark ? 3 : 4,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: CaptionPreviewCard.stageHeight,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final pulse = (1 - _pulseCtrl.value) * 0.12;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: isDark ? 0.3 : 0.22),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(const Color(0xFF242428), accent, pulse)!,
                      const Color(0xFF060608),
                    ],
                  ),
                ),
                child: child,
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _StageVignettePainter(accent: accent.withValues(alpha: 0.08)),
                ),
                if (widget.showSafeGuides)
                  CustomPaint(painter: _StageSafeGuidePainter()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
                  child: EditCaptionsPreviewOverlay(
                    l10n: widget.l10n,
                    layout: CaptionPreviewLayout.stage,
                    showPreviewLabel: false,
                    animateMotion: true,
                    motionDuration: const Duration(milliseconds: 180),
                    stylePreset: s.style,
                    fontSize: s.fontSize,
                    fontFamily: s.fontFamily,
                    position: s.position,
                    color: s.color,
                    wordHighlight: s.wordHighlight,
                    normalTextColor: s.normalTextColor,
                    activeTextColor: s.activeTextColor,
                    boxColor: s.boxColor,
                    boxShape: s.boxShape,
                    outlineEnabled: s.outlineEnabled,
                    outlineColor: s.outlineColor,
                    outlineWidth: s.outlineWidth,
                    offsetXAss: s.offsetX,
                    offsetYAss: s.offsetY,
                  ),
                ),
                if (widget.onFullscreen != null)
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: _FullscreenPreviewButton(
                      label: widget.l10n.editCaptionsV36FullscreenPreview,
                      onTap: widget.onFullscreen!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenPreviewButton extends StatelessWidget {
  const _FullscreenPreviewButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fullscreen_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageVignettePainter extends CustomPainter {
  _StageVignettePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final spotlight = RadialGradient(
      center: const Alignment(0, -0.15),
      radius: 0.85,
      colors: [
        accent.withValues(alpha: 0.35),
        Colors.transparent,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = spotlight.createShader(rect));

    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.05,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.55),
      ],
      stops: const [0.55, 1],
    );
    canvas.drawRect(rect, Paint()..shader = vignette.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _StageVignettePainter old) => old.accent != accent;
}

class _StageSafeGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final insetH = size.width * 0.16;
    final insetV = size.height * 0.22;
    final r = Rect.fromLTRB(
      insetH,
      insetV,
      size.width - insetH,
      size.height - insetV,
    );
    canvas.drawRect(r, paint);
    canvas.drawLine(
      Offset(size.width / 2, insetV),
      Offset(size.width / 2, size.height - insetV),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
