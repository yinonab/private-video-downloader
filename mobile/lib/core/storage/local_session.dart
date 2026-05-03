import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

import "../utils/url_utils.dart";

/// Persists MVP session: server URL in SharedPreferences; device secrets in secure storage.
class LocalSession extends ChangeNotifier {
  LocalSession();

  final FlutterSecureStorage _secure =
      const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static const _prefsServerKey = "server_base_url";
  static const _prefsDisplayKey = "device_display_name";

  bool _hydrated = false;
  String _serverUrl = "";
  String _deviceId = "";
  String _deviceToken = "";
  String? _displayName;

  /// Last URL handed from Share sheet before onboarding completes.
  String? pendingSharedUrl;

  bool get hydrated => _hydrated;

  bool get isRegistered =>
      (_deviceToken.trim().isNotEmpty) && UrlUtils.looksLikeHttpUrl(_serverUrl);

  String get serverUrl => _serverUrl;
  String get deviceId => _deviceId;

  /// Raw bearer string (already trimmed when stored).
  String get deviceToken => _deviceToken;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = UrlUtils.normalizeServerBase(prefs.getString(_prefsServerKey) ?? "");
    _displayName = prefs.getString(_prefsDisplayKey);

    var id = (await _secure.read(key: "device_id_secure"))?.trim();
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _secure.write(key: "device_id_secure", value: id);
    }
    _deviceId = id;

    final tok = await _secure.read(key: "device_token_secure");
    _deviceToken = tok?.trim() ?? "";

    _hydrated = true;
    notifyListeners();
  }

  Future<void> applyRegistration({
    required String rawServerUrl,
    required String newDeviceToken,
    required String stableDeviceId,
    String? deviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = UrlUtils.normalizeServerBase(rawServerUrl);

    await prefs.setString(_prefsServerKey, normalized);
    if (deviceName != null && deviceName.trim().isNotEmpty) {
      await prefs.setString(_prefsDisplayKey, deviceName.trim());
      _displayName = deviceName.trim();
    } else {
      await prefs.remove(_prefsDisplayKey);
      _displayName = null;
    }

    await _secure.write(key: "device_id_secure", value: stableDeviceId.trim());
    await _secure.write(key: "device_token_secure", value: newDeviceToken.trim());

    _serverUrl = normalized;
    _deviceId = stableDeviceId.trim();
    _deviceToken = newDeviceToken.trim();

    notifyListeners();
  }

  Future<void> updateServerUrl(String rawUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = UrlUtils.normalizeServerBase(rawUrl);
    await prefs.setString(_prefsServerKey, normalized);
    _serverUrl = normalized;
    notifyListeners();
  }

  Future<void> rememberDownloadPath({required String jobId, required String absolutePath}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("dl_path_$jobId", absolutePath);
  }

  Future<String?> localPathForJob(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("dl_path_$jobId");
  }

  Future<void> forgetDownloadPath(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("dl_path_$jobId");
  }

  Future<void> wipeDownloadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith("dl_path_"));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Deletes secure + prefs snapshot and rotates local UUID (invite required server-side anyway).
  Future<void> factoryResetLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await _secure.deleteAll();
    await prefs.clear();
    pendingSharedUrl = null;

    _serverUrl = "";
    _deviceToken = "";
    _displayName = null;

    final id = const Uuid().v4();
    await _secure.write(key: "device_id_secure", value: id);
    _deviceId = id;

    notifyListeners();
  }

  void stageSharedUrl(String raw) {
    final maybe = UrlUtils.extractFirst(raw) ?? (UrlUtils.looksLikeHttpUrl(raw) ? raw : null);
    if (maybe == null) return;
    pendingSharedUrl = UrlUtils.stripTrailingJunk(maybe);
    notifyListeners();
  }

  String? consumePendingShare() {
    final p = pendingSharedUrl?.trim();
    pendingSharedUrl = null;
    if (p == null || p.isEmpty) return null;
    notifyListeners();
    return UrlUtils.stripTrailingJunk(p);
  }
}
