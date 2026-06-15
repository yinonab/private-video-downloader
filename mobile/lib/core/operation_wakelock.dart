import "package:wakelock_plus/wakelock_plus.dart";

/// Best-effort screen wake lock for active foreground operations (analyze, download, edit).
///
/// Reference-counted so overlapping operations (e.g. edit export + caption draft) can each
/// acquire/release independently without fighting over the underlying platform wake lock.
abstract final class OperationWakelock {
  static int _holders = 0;

  static Future<void> acquire() async {
    _holders++;
    if (_holders != 1) return;
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Best-effort — some devices may reject wake lock.
    }
  }

  static Future<void> release() async {
    if (_holders <= 0) return;
    _holders--;
    if (_holders != 0) return;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
