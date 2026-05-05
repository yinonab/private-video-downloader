import "dart:io" show Platform;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/date_symbol_data_local.dart";
import "package:media_store_plus/media_store_plus.dart";

import "app.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = "PrivateVideoDownloader";
  }
  await Future.wait([
    initializeDateFormatting("en_US"),
    initializeDateFormatting("he_IL"),
  ]);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final navigatorKey = GlobalKey<NavigatorState>();
  final bootstrap = BootstrapCoordinator(navigatorKey: navigatorKey);

  runApp(PrivateDownloaderApp(controller: bootstrap));
}
