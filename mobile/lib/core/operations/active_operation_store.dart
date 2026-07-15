import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

import "active_operation.dart";

/// Single primary active operation persisted in SharedPreferences (V1).
final class ActiveOperationStore {
  ActiveOperationStore();

  static const _prefsKey = "active_operation_v1";
  static const _schemaVersion = 1;

  static const staleNonTerminal = Duration(days: 7);
  static const staleStartingWithoutJobId = Duration(minutes: 15);

  Future<ActiveOperation?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = ActiveOperation.decode(raw);
      if (decoded == null) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Reads and clears or marks stale non-terminal operations.
  Future<ActiveOperation?> readAndExpireStale() async {
    final op = await read();
    if (op == null) return null;
    final now = DateTime.now().toUtc();
    final age = now.difference(op.updatedAt);

    if (!op.hasBackendJobId &&
        op.status == OperationStatus.starting &&
        age > staleStartingWithoutJobId) {
      await clear();
      return null;
    }

    if (op.isNonTerminal && age > staleNonTerminal) {
      await clear();
      return null;
    }

    return op;
  }

  Future<ActiveOperation> save(ActiveOperation op) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, ActiveOperation.encode(op));
    return op;
  }

  Future<ActiveOperation> update(ActiveOperation op) => save(op);

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<ActiveOperation> markSuccess(ActiveOperation op) {
    final now = DateTime.now().toUtc();
    return save(
      op.copyWith(
        status: OperationStatus.success,
        updatedAt: now,
        clearErrorCode: true,
      ),
    );
  }

  Future<ActiveOperation> markFailed(ActiveOperation op, {String? errorCode}) {
    final now = DateTime.now().toUtc();
    return save(
      op.copyWith(
        status: OperationStatus.failed,
        errorCode: errorCode,
        updatedAt: now,
      ),
    );
  }

  Future<ActiveOperation> markCancelled(ActiveOperation op) {
    final now = DateTime.now().toUtc();
    return save(
      op.copyWith(
        status: OperationStatus.cancelled,
        updatedAt: now,
      ),
    );
  }

  static String newLocalOperationId() => const Uuid().v4();

  static int get schemaVersion => _schemaVersion;
}
