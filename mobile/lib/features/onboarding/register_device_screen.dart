import "dart:io" show Platform;

import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/models/api_error.dart";
import "../../core/models/device_models.dart";
import "../../core/network/api_client.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/app_text_field.dart";
import "../settings/settings_screen.dart";

class RegisterDeviceScreen extends StatefulWidget {
  const RegisterDeviceScreen({super.key});

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtl = TextEditingController();
  final _inviteCtl = TextEditingController();
  final _nameCtl = TextEditingController();

  bool _loading = false;
  String? _errorHe;

  @override
  void dispose() {
    _serverCtl.dispose();
    _inviteCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context).session;
      if (_serverCtl.text.isEmpty && s.serverUrl.isNotEmpty) {
        _serverCtl.text = s.serverUrl;
      }
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    if (!mounted) return;
    final s = AppScope.read(context).session;
    if (_serverCtl.text.isEmpty || !s.usesCustomServerUrl) {
      _serverCtl.text = s.serverUrl;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    setState(() => _errorHe = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final scope = AppScope.read(context);
    final session = scope.session;
    final baked = kApiBaseUrlFromDefine.trim().isNotEmpty;
    final showServerField = session.usesCustomServerUrl || !baked;

    final normalizedServer = ApiClient.normalizeServerInput(
      showServerField ? _serverCtl.text.trim() : session.serverUrl.trim(),
    );
    if (normalizedServer.isEmpty) {
      setState(() => _errorHe = "נא להזין כתובת שרת תקינה או לעדכן בהגדרות מתקדמות");
      return;
    }
    final parsed = Uri.tryParse(normalizedServer);
    if (parsed == null || !parsed.hasScheme) {
      setState(() => _errorHe = "כתובת השרת לא תקינה");
      return;
    }

    setState(() => _loading = true);
    try {
      final platform = Platform.isAndroid
          ? "android"
          : Platform.isIOS
              ? "ios"
              : Platform.operatingSystem;
      final inviteRaw = _inviteCtl.text.trim();
      final req = RegisterDeviceRequest(
        deviceId: session.deviceId,
        deviceName: _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim(),
        platform: platform,
        inviteCode: inviteRaw.isEmpty ? null : inviteRaw,
      );

      final base =
          ApiClient.normalizeServerInput(normalizedServer).trimRight().replaceAll(RegExp(r"/+$"), "");
      regDebugPrint("manual register screen submit");
      regDebugPrint("final register url=$base/devices/register");

      if (showServerField) {
        await session.setCustomServerEnabled(true);
      }

      final res = await scope.deviceService.register(req, normalizedServer);
      await session.applyRegistration(
        rawServerUrl: normalizedServer,
        newDeviceToken: res.deviceToken,
        stableDeviceId: res.deviceId.trim().isEmpty ? session.deviceId : res.deviceId,
        deviceName: _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim(),
      );
      regDebugPrint("token saved=true");
      regDebugPrint("navigating Home");
    } catch (e, st) {
      regDebugLogRegistrationFailure(e, st);
      final msg = e is ApiError ? e.localized : ApiError.fromUnknown(e).localized;
      setState(() => _errorHe = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final session = scope.session;
    final baked = kApiBaseUrlFromDefine.trim().isNotEmpty;
    final showServerField = session.usesCustomServerUrl || !baked;

    return Scaffold(
      appBar: AppBar(
        title: const Text("רישום מכשיר"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _loading ? null : _openSettings,
            tooltip: "הגדרות",
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!showServerField) ...[
                  Text("שרת", style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SelectableText(session.serverUrl.isEmpty ? "(לא מוגדר)" : session.serverUrl),
                  const SizedBox(height: 8),
                  Text(
                    "כתובת השרת נקבעה בגרסת האפליקציה. לשינוי — הגדרות ← מתקדם.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                ],
                if (showServerField) ...[
                  AppTextField(
                    controller: _serverCtl,
                    label: "כתובת שרת",
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) {
                      final raw = "${v ?? ""}".trim();
                      if (raw.isEmpty) return "חובה";
                      final n = ApiClient.normalizeServerInput(raw);
                      final parsed = Uri.tryParse(n);
                      if (n.isEmpty || parsed == null || !parsed.hasScheme) return "כתובת לא תקינה";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                AppTextField(
                  controller: _inviteCtl,
                  label: "קוד הזמנה (אופציונלי)",
                  autocorrect: false,
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _nameCtl, label: "שם מכשיר (אופציונלי)", autocorrect: false),
                if (_errorHe != null) ...[
                  const SizedBox(height: 16),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _errorHe!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                AppPrimaryButton(label: "רישום מכשיר", loading: _loading, onPressed: _loading ? null : _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
