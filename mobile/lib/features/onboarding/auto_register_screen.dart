import "dart:io" show Platform;

import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/models/api_error.dart";

/// Shown while the app POSTs `/devices/register` using the baked-in or default server URL.
class AutoRegisterScreen extends StatefulWidget {
  const AutoRegisterScreen({
    super.key,
    required this.busy,
    this.error,
    required this.onRetry,
    required this.onManualSetup,
  });

  final bool busy;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onManualSetup;

  @override
  State<AutoRegisterScreen> createState() => _AutoRegisterScreenState();
}

class _AutoRegisterScreenState extends State<AutoRegisterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context).session;
      final platform =
          Platform.isAndroid ? "android" : Platform.isIOS ? "ios" : Platform.operatingSystem;
      final deviceNameLabel =
          Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : Platform.operatingSystem;
      final base = s.serverUrl.trim().replaceAll(RegExp(r"/+$"), "");
      final registerUrl = "$base/devices/register";
      regDebugPrint("auto register screen opened");
      regDebugPrint("generated/loaded deviceId=${s.deviceId}");
      regDebugPrint("deviceName=$deviceNameLabel");
      regDebugPrint("platform=$platform");
      regDebugPrint("final register url=$registerUrl");
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("התחברות")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.busy) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 24),
                  Text("מתחבר לשרת…", textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                ],
                if (!widget.busy && widget.error != null) ...[
                  Icon(Icons.warning_amber_rounded, size: 52, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    widget.error is ApiError ? (widget.error! as ApiError).localized : "ההתחברות נכשלה",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: widget.onRetry, child: const Text("נסה שוב")),
                  const SizedBox(height: 12),
                  TextButton(onPressed: widget.onManualSetup, child: const Text("הגדרה ידנית / מתקדם")),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
