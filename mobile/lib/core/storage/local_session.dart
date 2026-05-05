import "package:flutter/foundation.dart";
import "package:flutter/material.dart" show ThemeMode;
import "package:flutter/widgets.dart" show Locale;
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:path/path.dart" as p;
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

import "../config/build_flags.dart";
import "../utils/download_media_naming.dart";
import "../utils/url_utils.dart";

/// Persisted under [LocalSession._prefsThemeModeKey] (`selected_theme_mode`).
enum ThemePreference {
  system,
  light,
  dark;

  static ThemePreference parseStored(String? raw) {
    switch (raw) {
      case "light":
        return ThemePreference.light;
      case "dark":
        return ThemePreference.dark;
      case "system":
      default:
        return ThemePreference.system;
    }
  }

  String get storageValue => switch (this) {
        ThemePreference.system => "system",
        ThemePreference.light => "light",
        ThemePreference.dark => "dark",
      };

  ThemeMode get materialThemeMode => switch (this) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };
}

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
  static const _prefsCustomServerKey = "custom_server_url_enabled";
  static const _prefsPreferManualRegisterKey = "prefer_manual_register";
  static const _prefsLocaleKey = "selected_locale";
  static const _prefsThemeModeKey = "selected_theme_mode";

  bool _hydrated = false;
  bool _customServerEnabled = false;
  bool _preferManualRegister = false;
  String _serverUrl = "";
  String _deviceId = "";
  String _deviceToken = "";
  String? _displayName;

  Locale _locale = const Locale("en");

  ThemePreference _themePreference = ThemePreference.system;

  /// Active UI locale (`en` default; persisted under [_prefsLocaleKey]).
  Locale get locale => _locale;

  /// Persisted appearance choice (default system).
  ThemePreference get themePreference => _themePreference;

  ThemeMode get themeMode => _themePreference.materialThemeMode;

  String? get displayName => _displayName;

  /// Last URL handed from Share sheet before onboarding completes.
  String? pendingSharedUrl;

  bool get hydrated => _hydrated;

  bool get isRegistered =>
      (_deviceToken.trim().isNotEmpty) && UrlUtils.looksLikeHttpUrl(_serverUrl);

  /// User chose "manual setup" after auto-register failed; cleared on successful registration or factory reset.
  bool get preferManualRegister => _preferManualRegister;

  /// True when the user chose a manual server URL (developer / LAN); otherwise [kApiBaseUrlFromDefine] applies when set.
  bool get usesCustomServerUrl => _customServerEnabled;

  String get serverUrl => _serverUrl;
  String get deviceId => _deviceId;

  /// Raw bearer string (already trimmed when stored).
  String get deviceToken => _deviceToken;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    final lang = prefs.getString(_prefsLocaleKey);
    _locale = lang == "he" ? const Locale("he") : const Locale("en");

    _themePreference = ThemePreference.parseStored(prefs.getString(_prefsThemeModeKey));

    _customServerEnabled = prefs.getBool(_prefsCustomServerKey) ?? false;

    if (_customServerEnabled) {
      _serverUrl = UrlUtils.normalizeServerBase(prefs.getString(_prefsServerKey) ?? "");
    } else {
      final baked = kApiBaseUrlFromDefine.trim();
      if (baked.isNotEmpty) {
        _serverUrl = UrlUtils.normalizeServerBase(baked);
        await prefs.setString(_prefsServerKey, _serverUrl);
      } else {
        _serverUrl = UrlUtils.normalizeServerBase(prefs.getString(_prefsServerKey) ?? "");
      }
    }

    _preferManualRegister = prefs.getBool(_prefsPreferManualRegisterKey) ?? false;

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

    final bakedRaw = kApiBaseUrlFromDefine.trim();
    final bakedNormalized =
        bakedRaw.isNotEmpty ? UrlUtils.normalizeServerBase(bakedRaw) : "";
    final bakedUrlValid =
        bakedRaw.isNotEmpty && UrlUtils.looksLikeHttpUrl(bakedNormalized);
    final hasDeviceToken = _deviceToken.trim().isNotEmpty;
    final shouldAutoRegister = !_preferManualRegister &&
        UrlUtils.looksLikeHttpUrl(_serverUrl) &&
        !hasDeviceToken;

    regDebugPrint("API_BASE_URL=$kApiBaseUrlFromDefine");
    regDebugPrint("bakedUrlValid=$bakedUrlValid");
    regDebugPrint("customServerEnabled=$_customServerEnabled");
    regDebugPrint("resolvedBaseUrl=$_serverUrl");
    regDebugPrint("hasDeviceToken=$hasDeviceToken");
    regDebugPrint("preferManualRegister=$_preferManualRegister");
    regDebugPrint("shouldAutoRegister=$shouldAutoRegister");

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode == "he" ? "he" : "en";
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLocaleKey, code);
    notifyListeners();
  }

  Future<void> setThemePreference(ThemePreference value) async {
    _themePreference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsThemeModeKey, value.storageValue);
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

    await prefs.remove(_prefsPreferManualRegisterKey);
    _preferManualRegister = false;

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

  Future<void> setPreferManualRegister(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_prefsPreferManualRegisterKey, true);
    } else {
      await prefs.remove(_prefsPreferManualRegisterKey);
    }
    _preferManualRegister = value;
    notifyListeners();
  }

  /// Persist manual-server mode and optionally set URL. When [enabled] is false, reapplies baked-in [kApiBaseUrlFromDefine] when present.
  Future<void> setCustomServerEnabled(bool enabled, {String? serverUrlRaw}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsCustomServerKey, enabled);
    _customServerEnabled = enabled;

    if (!enabled) {
      final baked = kApiBaseUrlFromDefine.trim();
      if (baked.isNotEmpty) {
        _serverUrl = UrlUtils.normalizeServerBase(baked);
        await prefs.setString(_prefsServerKey, _serverUrl);
      }
    } else if (serverUrlRaw != null && serverUrlRaw.trim().isNotEmpty) {
      await updateServerUrl(serverUrlRaw);
      return;
    }
    notifyListeners();
  }

  /// Clears bearer token only (keeps device id and server URL). Used when switching servers from settings.
  Future<void> clearRegistrationToken() async {
    await _secure.delete(key: "device_token_secure");
    _deviceToken = "";
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPreferManualRegisterKey);
    _preferManualRegister = false;
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
    final savedLang = prefs.getString(_prefsLocaleKey);
    final savedTheme = prefs.getString(_prefsThemeModeKey);
    await _secure.deleteAll();
    await prefs.clear();
    if (savedLang != null && savedLang.isNotEmpty) {
      await prefs.setString(_prefsLocaleKey, savedLang);
    }
    if (savedTheme != null && savedTheme.isNotEmpty) {
      await prefs.setString(_prefsThemeModeKey, savedTheme);
    }
    pendingSharedUrl = null;

    _serverUrl = "";
    _deviceToken = "";
    _displayName = null;
    _customServerEnabled = false;

    final id = const Uuid().v4();
    await _secure.write(key: "device_id_secure", value: id);
    _deviceId = id;

    await bootstrap();
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
