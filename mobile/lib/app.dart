import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";

import "core/app_scope.dart";
import "core/network/api_client.dart";
import "core/storage/local_session.dart";
import "core/theme/app_theme.dart";
import "features/analyze/analyze_screen.dart";
import "features/home/home_screen.dart";
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
    await session.bootstrap();

    _shareBridge = ShareIntentService(session: session, navigateIfReady: routeSharedAnalyze)..startListening();
  }

  void routeSharedAnalyze(String url) {
    final t = url.trim();
    if (t.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => AnalyzeScreen(initialUrl: t)));
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

  @override
  void dispose() {
    c.dispose();
    super.dispose();
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
              child: !c.session.hydrated
                  ? const Center(key: ValueKey("loading"), child: CircularProgressIndicator())
                  : c.session.isRegistered
                      ? const HomeScreen(key: ValueKey("home"))
                      : const RegisterDeviceScreen(key: ValueKey("register")),
            ),
          ),
        );
      },
    );
  }
}
