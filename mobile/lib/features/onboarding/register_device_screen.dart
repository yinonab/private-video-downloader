import "dart:io" show Platform;

import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/models/api_error.dart";
import "../../core/models/device_models.dart";
import "../../core/network/api_client.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/app_text_field.dart";

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

  Future<void> _submit() async {
    setState(() => _errorHe = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final scope = AppScope.read(context);
    setState(() => _loading = true);
    try {
      final platform = Platform.isAndroid
          ? "android"
          : Platform.isIOS
              ? "ios"
              : Platform.operatingSystem;
      final req = RegisterDeviceRequest(
        deviceId: scope.session.deviceId,
        deviceName: _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim(),
        platform: platform,
        inviteCode: _inviteCtl.text.trim(),
      );
      final normalizedServer = ApiClient.normalizeServerInput(_serverCtl.text.trim());
      if (normalizedServer.isEmpty) {
        throw ApiError(code: "BAD_REQUEST", message: "missing server", hebrewSummary: "נא להזין כתובת שרת תקינה");
      }
      final parsed = Uri.tryParse(normalizedServer);
      if (parsed == null || !parsed.hasScheme) {
        throw ApiError(code: "BAD_REQUEST", message: "bad url", hebrewSummary: "כתובת השרת לא תקינה");
      }
      final res = await scope.deviceService.register(req, _serverCtl.text.trim());
      await scope.session.applyRegistration(
        rawServerUrl: normalizedServer,
        newDeviceToken: res.deviceToken,
        stableDeviceId: res.deviceId.trim().isEmpty ? scope.session.deviceId : res.deviceId,
        deviceName: _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim(),
      );
    } catch (e) {
      final msg = e is ApiError ? e.localized : ApiError.fromUnknown(e).localized;
      setState(() => _errorHe = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("רישום מכשיר")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                AppTextField(
                  controller: _inviteCtl,
                  label: "קוד הזמנה",
                  autocorrect: false,
                  validator: (v) => (v == null || v.trim().isEmpty) ? "חובה" : null,
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
