import "package:flutter/widgets.dart";

import "../network/api_client.dart";
import "../storage/local_session.dart";
import "../../services/analyze_service.dart";
import "../../services/device_service.dart";
import "../../services/download_service.dart";
import "../../services/file_download_service.dart";

/// Application dependency container (InheritedWidget — no extra deps).
final class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.session,
    required this.api,
    required this.deviceService,
    required this.downloadService,
    required this.analyzeService,
    required this.files,
    required super.child,
  });

  final LocalSession session;
  final ApiClient api;
  final DeviceService deviceService;
  final DownloadService downloadService;
  final AnalyzeService analyzeService;
  final FileDownloadService files;

  static AppScope read(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return identical(oldWidget.session, session) == false ||
        identical(oldWidget.api, api) == false;
  }
}
