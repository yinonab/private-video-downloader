import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../../core/models/quick_edit_models.dart";

/// Draggable mini-joystick for caption position fine-tuning (V3.4F).
class CaptionPositionJoystick extends StatefulWidget {
  const CaptionPositionJoystick({
    super.key,
    required this.accentColor,
    required this.onNudge,
  });

  final Color accentColor;
  final void Function(int dxAss, int dyAss) onNudge;

  @override
  State<CaptionPositionJoystick> createState() => _CaptionPositionJoystickState();
}

class _CaptionPositionJoystickState extends State<CaptionPositionJoystick>
    with SingleTickerProviderStateMixin {
  static const double _padSize = 176;
  static const double _knobSize = 52;
  static const double _maxTravel = 24;
  static const double _stepPixels = 16;

  Offset _knobOffset = Offset.zero;
  bool _dragging = false;
  _JoystickDirection? _activeDir;
  double _accumDx = 0;
  double _accumDy = 0;

  late AnimationController _springCtrl;
  late Animation<Offset> _springAnim;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _springAnim = const AlwaysStoppedAnimation(Offset.zero);
    _springCtrl.addListener(() {
      if (!_dragging) {
        setState(() => _knobOffset = _springAnim.value);
      }
    });
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _springCtrl.dispose();
    super.dispose();
  }

  void _springBack() {
    final begin = _knobOffset;
    _springAnim = Tween<Offset>(begin: begin, end: Offset.zero).animate(
      CurvedAnimation(parent: _springCtrl, curve: Curves.easeOutBack),
    );
    _springCtrl.forward(from: 0);
  }

  void _setActiveDirFromOffset(Offset o) {
    if (o.distance < 4) {
      _activeDir = null;
      return;
    }
    final angle = math.atan2(o.dy, o.dx);
    if (angle >= -math.pi / 4 && angle < math.pi / 4) {
      _activeDir = _JoystickDirection.right;
    } else if (angle >= math.pi / 4 && angle < 3 * math.pi / 4) {
      _activeDir = _JoystickDirection.down;
    } else if (angle >= -3 * math.pi / 4 && angle < -math.pi / 4) {
      _activeDir = _JoystickDirection.up;
    } else {
      _activeDir = _JoystickDirection.left;
    }
  }

  void _applyAccumulatedDrag() {
    final step = kQuickEditCaptionsOffsetFineStep;
    var haptic = false;

    while (_accumDx >= _stepPixels) {
      widget.onNudge(step, 0);
      _accumDx -= _stepPixels;
      haptic = true;
    }
    while (_accumDx <= -_stepPixels) {
      widget.onNudge(-step, 0);
      _accumDx += _stepPixels;
      haptic = true;
    }
    while (_accumDy >= _stepPixels) {
      widget.onNudge(0, step);
      _accumDy -= _stepPixels;
      haptic = true;
    }
    while (_accumDy <= -_stepPixels) {
      widget.onNudge(0, -step);
      _accumDy += _stepPixels;
      haptic = true;
    }
    if (haptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _onPanStart(DragStartDetails _) {
    _springCtrl.stop();
    _repeatTimer?.cancel();
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _knobOffset += d.delta;
      if (_knobOffset.distance > _maxTravel) {
        _knobOffset = Offset.fromDirection(
          _knobOffset.direction,
          _maxTravel,
        );
      }
      _setActiveDirFromOffset(_knobOffset);
      _accumDx += d.delta.dx;
      _accumDy += d.delta.dy;
      _applyAccumulatedDrag();
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _accumDx = 0;
    _accumDy = 0;
    setState(() {
      _dragging = false;
      _activeDir = null;
    });
    _springBack();
  }

  void _nudgeDirection(_JoystickDirection dir) {
    final step = kQuickEditCaptionsOffsetFineStep;
    switch (dir) {
      case _JoystickDirection.up:
        widget.onNudge(0, -step);
      case _JoystickDirection.down:
        widget.onNudge(0, step);
      case _JoystickDirection.left:
        widget.onNudge(-step, 0);
      case _JoystickDirection.right:
        widget.onNudge(step, 0);
    }
    HapticFeedback.selectionClick();
    setState(() {
      _activeDir = dir;
      _knobOffset = switch (dir) {
        _JoystickDirection.up => const Offset(0, -14),
        _JoystickDirection.down => const Offset(0, 14),
        _JoystickDirection.left => const Offset(-14, 0),
        _JoystickDirection.right => const Offset(14, 0),
      };
    });
    _springCtrl.stop();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted || _dragging) return;
      setState(() => _activeDir = null);
      _springBack();
    });
  }

  void _onTapDown(TapDownDetails d) {
    final local = d.localPosition - Offset(_padSize / 2, _padSize / 2);
    if (local.distance < _knobSize * 0.55) return;
    final dir = _directionFromOffset(local);
    if (dir != null) _nudgeDirection(dir);
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final local = d.localPosition - Offset(_padSize / 2, _padSize / 2);
    final dir = _directionFromOffset(local);
    if (dir == null) return;
    _nudgeDirection(dir);
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (!mounted) return;
      _nudgeDirection(dir);
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _repeatTimer?.cancel();
    if (!_dragging) _springBack();
  }

  _JoystickDirection? _directionFromOffset(Offset local) {
    if (local.distance < _knobSize * 0.5) return null;
    _setActiveDirFromOffset(local);
    return _activeDir;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTapDown: _onTapDown,
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: _onLongPressEnd,
          onLongPressCancel: () => _repeatTimer?.cancel(),
          child: SizedBox(
            width: _padSize,
            height: _padSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: _padSize,
                  height: _padSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.surfaceContainerHigh.withValues(
                          alpha: isDark ? 0.85 : 0.98,
                        ),
                        scheme.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.55 : 0.75,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: _dragging
                          ? accent.withValues(alpha: 0.65)
                          : scheme.outline.withValues(alpha: 0.25),
                      width: _dragging ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _dragging
                            ? accent.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.12),
                        blurRadius: _dragging ? 18 : 10,
                        spreadRadius: _dragging ? 1 : 0,
                      ),
                    ],
                  ),
                ),
                ..._JoystickDirection.values.map(
                  (d) => _DirectionHint(
                    direction: d,
                    active: _activeDir == d,
                    accent: accent,
                    padSize: _padSize,
                  ),
                ),
                Transform.translate(
                  offset: _knobOffset,
                  child: AnimatedScale(
                    scale: _dragging ? 0.92 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: _JoystickKnob(
                      size: _knobSize,
                      accent: accent,
                      dragging: _dragging,
                      scheme: scheme,
                      isDark: isDark,
                    ),
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

enum _JoystickDirection { up, down, left, right }

class _DirectionHint extends StatelessWidget {
  const _DirectionHint({
    required this.direction,
    required this.active,
    required this.accent,
    required this.padSize,
  });

  final _JoystickDirection direction;
  final bool active;
  final Color accent;
  final double padSize;

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      _JoystickDirection.up => Icons.keyboard_arrow_up_rounded,
      _JoystickDirection.down => Icons.keyboard_arrow_down_rounded,
      _JoystickDirection.left => Icons.keyboard_arrow_left_rounded,
      _JoystickDirection.right => Icons.keyboard_arrow_right_rounded,
    };
    final alignment = switch (direction) {
      _JoystickDirection.up => Alignment.topCenter,
      _JoystickDirection.down => Alignment.bottomCenter,
      _JoystickDirection.left => Alignment.centerLeft,
      _JoystickDirection.right => Alignment.centerRight,
    };

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: AnimatedOpacity(
          opacity: active ? 1 : 0.28,
          duration: const Duration(milliseconds: 120),
          child: Icon(
            icon,
            size: 20,
            color: active
                ? accent
                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _JoystickKnob extends StatelessWidget {
  const _JoystickKnob({
    required this.size,
    required this.accent,
    required this.dragging,
    required this.scheme,
    required this.isDark,
  });

  final double size;
  final Color accent;
  final bool dragging;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: isDark ? 0.95 : 1),
            scheme.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: dragging
              ? accent.withValues(alpha: 0.7)
              : scheme.outline.withValues(alpha: 0.3),
          width: dragging ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: dragging
                ? accent.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: dragging ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dragging
                ? accent.withValues(alpha: 0.9)
                : scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
