import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/date_symbol_data_local.dart";

import "app.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting("he_IL");
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final navigatorKey = GlobalKey<NavigatorState>();
  final bootstrap = BootstrapCoordinator(navigatorKey: navigatorKey);

  await bootstrap.bootstrap();

  runApp(PrivateDownloaderApp(controller: bootstrap));
}
