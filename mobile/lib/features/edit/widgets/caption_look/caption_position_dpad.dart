import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../../core/models/quick_edit_models.dart";

/// Direction on the caption position D-pad.
enum CaptionDpadDirection { up, down, left, right }

/// Controller-inspired D-pad for caption position fine-tuning (V3.4G).
class CaptionPositionDPad extends StatelessWidget {
  const CaptionPositionDPad({
    super.key,
    required this.accentColor,
    required this.onNudge,
  });

  final Color accentColor;
  final void Function(int dxAss, int dyAss) onNudge;

  static const double _controlSize = 184;
  static const double _btnSize = 58;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final center = (_controlSize - _btnSize) / 2;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: _controlSize,
          height: _controlSize,
          child: Stack(
            children: [
              Positioned(
                left: center,
                top: 0,
                child: CaptionDpadButton(
                  direction: CaptionDpadDirection.up,
                  accentColor: accentColor,
                  onNudge: onNudge,
                ),
              ),
              Positioned(
                left: center,
                bottom: 0,
                child: CaptionDpadButton(
                  direction: CaptionDpadDirection.down,
                  accentColor: accentColor,
                  onNudge: onNudge,
                ),
              ),
              Positioned(
                left: 0,
                top: center,
                child: CaptionDpadButton(
                  direction: CaptionDpadDirection.left,
                  accentColor: accentColor,
                  onNudge: onNudge,
                ),
              ),
              Positioned(
                right: 0,
                top: center,
                child: CaptionDpadButton(
                  direction: CaptionDpadDirection.right,
                  accentColor: accentColor,
                  onNudge: onNudge,
                ),
              ),
              Positioned(
                left: center + (_btnSize - _gap) / 2,
                top: center + (_btnSize - _gap) / 2,
                child: const _DpadCenterHub(size: _gap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DpadCenterHub extends StatelessWidget {
  const _DpadCenterHub({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
      ),
    );
  }
}

/// Single raised directional button on the D-pad cross.
class CaptionDpadButton extends StatefulWidget {
  const CaptionDpadButton({
    super.key,
    required this.direction,
    required this.accentColor,
    required this.onNudge,
  });

  final CaptionDpadDirection direction;
  final Color accentColor;
  final void Function(int dxAss, int dyAss) onNudge;

  static const double size = 58;

  @override
  State<CaptionDpadButton> createState() => _CaptionDpadButtonState();
}

class _CaptionDpadButtonState extends State<CaptionDpadButton> {
  bool _pressed = false;
  Timer? _repeatTimer;

  static const Duration _repeatInterval = Duration(milliseconds: 140);

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _nudgeOnce() {
    final step = kQuickEditCaptionsOffsetFineStep;
    switch (widget.direction) {
      case CaptionDpadDirection.up:
        widget.onNudge(0, -step);
      case CaptionDpadDirection.down:
        widget.onNudge(0, step);
      case CaptionDpadDirection.left:
        widget.onNudge(-step, 0);
      case CaptionDpadDirection.right:
        widget.onNudge(step, 0);
    }
    HapticFeedback.selectionClick();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _pressed = true);
    _nudgeOnce();
  }

  void _onTapUp(TapUpDetails _) {
    _release();
  }

  void _onTapCancel() {
    _release();
  }

  void _release() {
    _repeatTimer?.cancel();
    if (_pressed) setState(() => _pressed = false);
  }

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _pressed = true);
    _nudgeOnce();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(_repeatInterval, (_) => _nudgeOnce());
  }

  void _onLongPressEnd(LongPressEndDetails _) => _release();

  void _onLongPressCancel() => _release();

  IconData get _icon => switch (widget.direction) {
        CaptionDpadDirection.up => Icons.keyboard_arrow_up_rounded,
        CaptionDpadDirection.down => Icons.keyboard_arrow_down_rounded,
        CaptionDpadDirection.left => Icons.keyboard_arrow_left_rounded,
        CaptionDpadDirection.right => Icons.keyboard_arrow_right_rounded,
      };

  BorderRadius get _radius => switch (widget.direction) {
        CaptionDpadDirection.up => const BorderRadius.vertical(
            top: Radius.circular(14),
            bottom: Radius.circular(8),
          ),
        CaptionDpadDirection.down => const BorderRadius.vertical(
            top: Radius.circular(8),
            bottom: Radius.circular(14),
          ),
        CaptionDpadDirection.left => const BorderRadius.horizontal(
            left: Radius.circular(14),
            right: Radius.circular(8),
          ),
        CaptionDpadDirection.right => const BorderRadius.horizontal(
            left: Radius.circular(8),
            right: Radius.circular(14),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor;

    final faceTop = isDark
        ? scheme.surfaceContainerHigh
        : const Color(0xFFF4F4F6);
    final faceBottom = isDark
        ? scheme.surfaceContainerHighest
        : const Color(0xFFE6E6EA);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 160),
        curve: _pressed ? Curves.easeIn : Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _pressed ? 90 : 160),
          width: CaptionDpadButton.size,
          height: CaptionDpadButton.size,
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.12),
                    ]
                  : [faceTop, faceBottom],
            ),
            border: Border.all(
              color: _pressed
                  ? accent.withValues(alpha: 0.55)
                  : scheme.outline.withValues(alpha: isDark ? 0.28 : 0.2),
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.7),
                      blurRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
          ),
          child: Icon(
            _icon,
            size: 24,
            color: _pressed
                ? accent.withValues(alpha: 0.95)
                : scheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ),
    );
  }
}
