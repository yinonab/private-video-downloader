import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:private_video_downloader/app.dart";
import "package:private_video_downloader/core/widgets/branded_loading.dart";

void main() {
  testWidgets("PrivateDownloaderApp builds before session hydrate", (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final navigatorKey = GlobalKey<NavigatorState>();
    final coordinator = BootstrapCoordinator(navigatorKey: navigatorKey);

    await tester.pumpWidget(PrivateDownloaderApp(controller: coordinator));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(BrandedLoadingPanel), findsOneWidget);
  });
}
