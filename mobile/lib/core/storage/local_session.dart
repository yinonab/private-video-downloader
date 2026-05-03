import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:path/path.dart" as p;
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

import "../utils/download_media_naming.dart";
import "../utils/url_utils.dart";

final class SavedDownloadDescriptor {
  SavedDownloadDescriptor({
    required this.internalPath,
    this.publicUri,
    required this.shareFileName,
    required this.mimeType,
    required this.fileSizeBytes,
  });

  /// App-private absolute path used for פתח / שתף (always preferred when valid).
  final String internalPath;

  /// Optional MediaStore `content://` URI after publishing to Downloads (user-visible copy).
  final String? publicUri;

  final String shareFileName;
  final String mimeType;
  final int fileSizeBytes;
}

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

  Future<void> rememberSavedDownload({
    required String jobId,
    required String internalPath,
    String? publicUri,
    required String shareFileName,
    required String mimeType,
    required int fileSizeBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("dl_internal_$jobId", internalPath.trim());
    final pu = publicUri?.trim();
    if (pu != null && pu.isNotEmpty) {
      await prefs.setString("dl_public_uri_$jobId", pu);
    } else {
      await prefs.remove("dl_public_uri_$jobId");
    }
    await prefs.setString("dl_name_$jobId", shareFileName.trim());
    await prefs.setString("dl_mime_$jobId", mimeType.trim());
    await prefs.setInt("dl_size_$jobId", fileSizeBytes);

    await prefs.remove("dl_path_$jobId");
  }

  Future<SavedDownloadDescriptor?> savedDownloadForJob(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final internalRaw = prefs.getString("dl_internal_$jobId");
    final publicRaw = prefs.getString("dl_public_uri_$jobId");
    final legacyPath = prefs.getString("dl_path_$jobId");

    String? internal = (internalRaw != null && internalRaw.trim().isNotEmpty) ? internalRaw.trim() : null;
    String? publicUri = (publicRaw != null && publicRaw.trim().isNotEmpty) ? publicRaw.trim() : null;

    if (internal == null && legacyPath != null && legacyPath.trim().isNotEmpty) {
      final leg = legacyPath.trim();
      if (!leg.startsWith("content:")) {
        internal = leg;
      } else {
        publicUri ??= leg;
      }
    }

    if (internal == null || internal.isEmpty) return null;

    final nameRaw = prefs.getString("dl_name_$jobId");
    final mimeRaw = prefs.getString("dl_mime_$jobId");
    final name = (nameRaw != null && nameRaw.trim().isNotEmpty) ? nameRaw.trim() : p.basename(internal);
    final mime = (mimeRaw != null && mimeRaw.trim().isNotEmpty)
        ? mimeRaw.trim()
        : DownloadMediaNaming.mimeFromExtension(_extensionFromRef(internal, name));
    final size = prefs.getInt("dl_size_$jobId") ?? 0;

    return SavedDownloadDescriptor(
      internalPath: internal,
      publicUri: publicUri,
      shareFileName: name,
      mimeType: mime,
      fileSizeBytes: size,
    );
  }

  static String _extensionFromRef(String ref, String shareName) {
    var ext = p.extension(shareName);
    if (ext.isEmpty) {
      ext = p.extension(ref);
    }
    return ext;
  }

  /// Legacy helper label for logs / fallbacks.
  static String storageRefLabel(String ref) {
    if (ref.startsWith("content:")) return ref;
    final parts = ref.split(RegExp(r"[\\/]"));
    return parts.isEmpty ? ref : parts.last;
  }

  Future<String?> localPathForJob(String jobId) async {
    final d = await savedDownloadForJob(jobId);
    return d?.internalPath;
  }

  Future<void> forgetDownloadPath(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("dl_internal_$jobId");
    await prefs.remove("dl_public_uri_$jobId");
    await prefs.remove("dl_path_$jobId");
    await prefs.remove("dl_name_$jobId");
    await prefs.remove("dl_mime_$jobId");
    await prefs.remove("dl_size_$jobId");
  }

  Future<void> wipeDownloadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
          (k) =>
              k.startsWith("dl_internal_") ||
              k.startsWith("dl_public_uri_") ||
              k.startsWith("dl_path_") ||
              k.startsWith("dl_name_") ||
              k.startsWith("dl_mime_") ||
              k.startsWith("dl_size_"),
        );
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
