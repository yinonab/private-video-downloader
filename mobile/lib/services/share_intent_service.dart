import "dart:async";
import "dart:io";

import "package:flutter/widgets.dart";
import "package:receive_sharing_intent/receive_sharing_intent.dart";

import "../core/storage/local_session.dart";
import "../core/utils/url_utils.dart";

/// Android share target integration (cold + warm paths).
final class ShareIntentService {
  ShareIntentService({required this.session, required this.navigateIfReady});

  final LocalSession session;

  /// Called with a sanitized URL whenever the router may push [AnalyzeRoute].
  final ValueSetter<String> navigateIfReady;

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  void startListening() {
    ReceiveSharingIntent.instance.getInitialMedia().then(_consume);
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(_consume, onError: (_) {});
  }

  Future<void> _consume(List<SharedMediaFile> batch) async {
    if (batch.isEmpty) return;
    final url = await _firstShareUrl(batch);
    if ((url ?? "").isEmpty) return;
    final clean = UrlUtils.stripTrailingJunk(url!.trim());

    await ReceiveSharingIntent.instance.reset();

    if (session.isRegistered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateIfReady(clean);
      });
      return;
    }

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
            final guessed = UrlUtils.extractFirst(txt) ?? (UrlUtils.looksLikeHttpUrl(txt.trim()) ? txt.trim() : null);
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
