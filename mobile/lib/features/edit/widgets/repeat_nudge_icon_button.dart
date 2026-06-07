import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Tap once or long-press to repeat [onStep] until release.
class RepeatNudgeIconButton extends StatefulWidget {
  const RepeatNudgeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onStep,
    this.initialDelay = const Duration(milliseconds: 360),
    this.repeatInterval = const Duration(milliseconds: 100),
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onStep;
  final Duration initialDelay;
  final Duration repeatInterval;

  @override
  State<RepeatNudgeIconButton> createState() => _RepeatNudgeIconButtonState();
}

class _RepeatNudgeIconButtonState extends State<RepeatNudgeIconButton> {
  Timer? _initialTimer;
  Timer? _repeatTimer;

  @override
  void dispose() {
    _cancelRepeat();
    super.dispose();
  }

  void _cancelRepeat() {
    _initialTimer?.cancel();
    _initialTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _fireStep() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    widget.onStep();
  }

  void _startRepeat() {
    _cancelRepeat();
    _initialTimer = Timer(widget.initialDelay, () {
      if (!mounted) return;
      _repeatTimer = Timer.periodic(widget.repeatInterval, (_) => _fireStep());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _fireStep();
          _startRepeat();
        },
        onPointerUp: (_) => _cancelRepeat(),
        onPointerCancel: (_) => _cancelRepeat(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(widget.icon),
        ),
      ),
    );
  }
}
