import "package:flutter/material.dart";

import "core/app_scope.dart";
import "core/config/build_flags.dart";
import "core/edit_history/local_edit_history_store.dart";
import "core/network/api_client.dart";
import "core/storage/local_session.dart";
import "core/theme/app_theme.dart";
import "core/widgets/bootstrap_gate.dart";
import "features/analyze/analyze_screen.dart";
import "features/home/home_screen.dart";
import "features/onboarding/register_device_screen.dart";
import "services/analyze_service.dart";
import "services/device_service.dart";
import "services/download_service.dart";
import "services/file_download_service.dart";
import "services/share_intent_service.dart";
import "l10n/app_localizations.dart";

final class BootstrapCoordinator {
  BootstrapCoordinator({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  final LocalSession session = LocalSession();
  late final ApiClient api = ApiClient(session: session);
  final LocalEditHistoryStore editHistory = LocalEditHistoryStore();

  ShareIntentService? _shareBridge;

  Future<void> bootstrap() async {
    await session.bootstrap();
    await editHistory.hydrate();

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

  bool _coordinatorBootstrapped = false;

  @override
  void initState() {
    super.initState();
    c.session.addListener(_onSessionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_coordinatorBootstrapped) {
        _coordinatorBootstrapped = true;
        await c.bootstrap();
      }
      if (!mounted) return;
      _onSessionChange();
    });
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

    setState(() {});
  }

  Widget _homeGate() {
    final s = c.session;
    if (!s.hydrated) {
      return BootstrapGate(key: const ValueKey("bootstrap_gate"), session: s);
    }
    if (s.isRegistered) {
      return const HomeScreen(key: ValueKey("home"));
    }

    /// Fresh / unregistered users always tap **Register device** (no silent auto-register).
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
          editHistory: c.editHistory,
          child: MaterialApp(
            navigatorKey: c.navigatorKey,
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            locale: c.session.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            themeMode: c.session.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
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
