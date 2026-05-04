import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:receive_sharing_intent/receive_sharing_intent.dart";

import "../core/config/build_flags.dart";
import "../core/storage/local_session.dart";
import "../core/utils/url_utils.dart";

/// Android share target integration (cold + warm paths; text/plain via plugin PATH field).
final class ShareIntentService {
  ShareIntentService({
    required this.navigatorKey,
    required this.session,
    required this.navigateIfReady,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final LocalSession session;

  /// Called with a sanitized URL whenever we should open [AnalyzeScreen].
  final ValueSetter<String> navigateIfReady;

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  String? _lastDigest;
  DateTime? _lastHandledAt;

  bool _isDuplicate(String digest) {
    final now = DateTime.now();
    if (_lastDigest == digest &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 3)) {
      return true;
    }
    _lastDigest = digest;
    _lastHandledAt = now;
    return false;
  }

  void _snack(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void startListening() {
    shareDebugPrint("share listener initialized");
    ReceiveSharingIntent.instance.getInitialMedia().then(_consume, onError: (Object e, StackTrace st) {
      shareDebugPrint("getInitialMedia error=$e stack=$st");
    });
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _consume,
      onError: (Object e) => shareDebugPrint("share stream error=$e"),
    );
  }

  Future<void> _consume(List<SharedMediaFile> batch) async {
    if (batch.isEmpty) return;

    final digest = batch.map((e) => "${e.path}|${e.mimeType}|${e.type.value}").join(";");
    if (_isDuplicate(digest)) {
      shareDebugPrint("duplicate share skipped");
      await ReceiveSharingIntent.instance.reset();
      return;
    }

    shareDebugPrint(
      "shared payload received paths=${batch.map((e) => e.path.length > 120 ? "${e.path.substring(0, 120)}…" : e.path).join(" :: ")}",
    );

    final url = await _firstShareUrl(batch);
    await ReceiveSharingIntent.instance.reset();

    if ((url ?? "").isEmpty) {
      shareDebugPrint("no URL found");
      _snack("לא נמצא קישור לשיתוף");
      return;
    }
    final clean = UrlUtils.stripTrailingJunk(url!.trim());
    shareDebugPrint("extracted URL=$clean");

    if (session.isRegistered) {
      shareDebugPrint("navigating to Analyze (registered)");
      WidgetsBinding.instance.addPostFrameCallback((_) => navigateIfReady(clean));
      return;
    }

    shareDebugPrint("pending URL stored (awaiting registration)");
    session.stageSharedUrl(clean);
  }

  static Future<String?> _firstShareUrl(List<SharedMediaFile> batch) async {
    for (final media in batch) {
      final fromPath = media.path.trim();

      if (UrlUtils.looksLikeHttpUrl(fromPath)) return fromPath;

      try {
        if (fromPath.isNotEmpty) {
          final file = File(fromPath);
          if (await file.exists()) {
            final txt = await file.readAsString();
            final guessed =
                UrlUtils.extractFirst(txt) ?? (UrlUtils.looksLikeHttpUrl(txt.trim()) ? txt.trim() : null);
            if (guessed != null && guessed.trim().isNotEmpty) return guessed.trim();
          }
        }
      } catch (_) {}

      final fallback = UrlUtils.extractFirst(fromPath);
      if (fallback != null) return fallback.trim();
    }
    return null;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
