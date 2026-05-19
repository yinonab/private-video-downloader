import "package:flutter/widgets.dart";
import "package:private_video_downloader/core/edit_history/local_edit_history_store.dart";
import "package:private_video_downloader/core/network/api_client.dart";
import "package:private_video_downloader/core/storage/local_session.dart";
import "package:private_video_downloader/services/analyze_service.dart";
import "package:private_video_downloader/services/device_service.dart";
import "package:private_video_downloader/services/download_service.dart";
import "package:private_video_downloader/services/file_download_service.dart";

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
    required this.editHistory,
    required super.child,
  });

  final LocalSession session;
  final ApiClient api;
  final DeviceService deviceService;
  final DownloadService downloadService;
  final AnalyzeService analyzeService;
  final FileDownloadService files;
  final LocalEditHistoryStore editHistory;

  static AppScope read(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return identical(oldWidget.session, session) == false ||
        identical(oldWidget.api, api) == false ||
        identical(oldWidget.editHistory, editHistory) == false;
  }
}
