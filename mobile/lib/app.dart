import "dart:io" show Platform;

import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";

import "core/app_scope.dart";
import "core/config/build_flags.dart";
import "core/models/device_models.dart";
import "core/network/api_client.dart";
import "core/storage/local_session.dart";
import "core/theme/app_theme.dart";
import "core/utils/url_utils.dart";
import "features/analyze/analyze_screen.dart";
import "features/home/home_screen.dart";
import "features/onboarding/auto_register_screen.dart";
import "features/onboarding/register_device_screen.dart";
import "services/analyze_service.dart";
import "services/device_service.dart";
import "services/download_service.dart";
import "services/file_download_service.dart";
import "services/share_intent_service.dart";

final class BootstrapCoordinator {
  BootstrapCoordinator({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  final LocalSession session = LocalSession();
  late final ApiClient api = ApiClient(session: session);

  ShareIntentService? _shareBridge;

  Future<void> bootstrap() async {
    regDebugPrint("app bootstrap started");
    await session.bootstrap();

    _shareBridge = ShareIntentService(
      navigatorKey: navigatorKey,
      session: session,
      navigateIfReady: routeSharedAnalyze,
    )..startListening();
  }

  void routeSharedAnalyze(String url) {
    final t = url.trim();
    if (t.isEmpty) return;

    shareDebugPrint("navigation to Analyze url=$t autoAnalyze=true");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.popUntil((route) => route.isFirst);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => AnalyzeScreen(key: ValueKey<String>("analyze|$t"), initialUrl: t),
        ),
      );
    });
  }

  void dispose() {
    _shareBridge?.dispose();
  }
}

class PrivateDownloaderApp extends StatefulWidget {
  const PrivateDownloaderApp({super.key, required this.controller});

  final BootstrapCoordinator controller;

  @override
  State<PrivateDownloaderApp> createState() => _PrivateDownloaderAppState();
}

class _PrivateDownloaderAppState extends State<PrivateDownloaderApp> {
  BootstrapCoordinator get c => widget.controller;

  bool _autoBusy = false;
  bool _autoRunning = false;
  Object? _autoErr;

  @override
  void initState() {
    super.initState();
    c.session.addListener(_onSessionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSessionChange());
  }

  @override
  void dispose() {
    c.session.removeListener(_onSessionChange);
    c.dispose();
    super.dispose();
  }

  void _onSessionChange() {
    if (!mounted) return;
    final s = c.session;
    if (!s.hydrated) return;

    if (s.isRegistered) {
      final pending = s.consumePendingShare();
      if (pending != null && pending.isNotEmpty) {
        shareDebugPrint("pending URL processed after bootstrap url=$pending");
        c.routeSharedAnalyze(pending);
      }
    }

    if (s.deviceToken.trim().isEmpty && _autoErr != null && !s.preferManualRegister) {
      setState(() => _autoErr = null);
    }

    if (!s.isRegistered &&
        !s.preferManualRegister &&
        UrlUtils.looksLikeHttpUrl(s.serverUrl) &&
        s.deviceToken.trim().isEmpty) {
      if (_autoBusy || _autoRunning || _autoErr != null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoRegister());
    }
  }

  Future<void> _runAutoRegister() async {
    if (!mounted || _autoRunning) return;
    final s = c.session;
    if (s.preferManualRegister || s.isRegistered) return;
    if (!UrlUtils.looksLikeHttpUrl(s.serverUrl)) return;
    if (s.deviceToken.trim().isNotEmpty) return;

    _autoRunning = true;
    setState(() {
      _autoBusy = true;
      _autoErr = null;
    });
    try {
      final platform =
          Platform.isAndroid ? "android" : Platform.isIOS ? "ios" : Platform.operatingSystem;
      final deviceNameLabel =
          Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : Platform.operatingSystem;
      final req = RegisterDeviceRequest(
        deviceId: s.deviceId,
        deviceName: deviceNameLabel,
        platform: platform,
        inviteCode: null,
      );
      final res = await DeviceService(c.api).register(req, s.serverUrl);
      final sid = res.deviceId.trim().isEmpty ? s.deviceId : res.deviceId.trim();
      await s.applyRegistration(
        rawServerUrl: s.serverUrl,
        newDeviceToken: res.deviceToken,
        stableDeviceId: sid,
        deviceName: deviceNameLabel,
      );
      regDebugPrint("token saved=true");
      regDebugPrint("navigating Home");
    } catch (e, st) {
      regDebugLogRegistrationFailure(e, st);
      if (mounted) setState(() => _autoErr = e);
    } finally {
      _autoRunning = false;
      if (mounted) setState(() => _autoBusy = false);
    }
  }

  Widget _homeGate() {
    final s = c.session;
    if (!s.hydrated) {
      return const Center(key: ValueKey("loading"), child: CircularProgressIndicator());
    }
    if (s.isRegistered) {
      return const HomeScreen(key: ValueKey("home"));
    }

    final urlOk = UrlUtils.looksLikeHttpUrl(s.serverUrl);

    if (!s.preferManualRegister && urlOk && s.deviceToken.trim().isEmpty) {
      return AutoRegisterScreen(
        key: const ValueKey("autoReg"),
        busy: _autoBusy,
        error: _autoErr,
        onRetry: () {
          setState(() => _autoErr = null);
          _runAutoRegister();
        },
        onManualSetup: () {
          c.session.setPreferManualRegister(true);
        },
      );
    }

    return const RegisterDeviceScreen(key: ValueKey("register"));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c.session,
      builder: (context, _) {
        final fileSvc = FileDownloadService(api: c.api, session: c.session);
        return AppScope(
          session: c.session,
          api: c.api,
          deviceService: DeviceService(c.api),
          downloadService: DownloadService(c.api),
          analyzeService: AnalyzeService(c.api),
          files: fileSvc,
          child: MaterialApp(
            navigatorKey: c.navigatorKey,
            debugShowCheckedModeBanner: false,
            title: "Private Video Downloader",
            locale: const Locale("he", "IL"),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale("he", "IL"),
              Locale("en", "US"),
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
            themeMode: ThemeMode.system,
            theme: AppTheme.theme(Brightness.light),
            darkTheme: AppTheme.theme(Brightness.dark),
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _homeGate(),
            ),
          ),
        );
      },
    );
  }
}
