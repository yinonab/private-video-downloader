import "dart:io" show Platform;

import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/device_models.dart";
import "../../core/network/api_client.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/utils/url_utils.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/app_text_field.dart";
import "../../core/widgets/language_picker.dart";
import "../settings/settings_screen.dart";

/// Minimal onboarding: user taps **Register device**; bundled API URL is used automatically.
class RegisterDeviceScreen extends StatefulWidget {
  const RegisterDeviceScreen({super.key});

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen> {
  final _inviteCtl = TextEditingController();

  bool _loading = false;
  bool _showInviteField = false;
  String? _errorUx;

  @override
  void dispose() {
    _inviteCtl.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() => _errorUx = null);

    final scope = AppScope.read(context);
    final session = scope.session;
    if (!session.hydrated) return;

    final normalizedServer = ApiClient.normalizeServerInput(session.effectiveApiBaseUrl);
    if (!UrlUtils.looksLikeHttpUrl(normalizedServer)) {
      setState(() => _errorUx = l10n.errorServerUrlInvalidConfig);
      return;
    }
    final parsed = Uri.tryParse(normalizedServer);
    if (parsed == null || !parsed.hasScheme) {
      setState(() => _errorUx = l10n.errorServerUrlInvalidConfig);
      return;
    }

    final platform = Platform.isAndroid
        ? "android"
        : Platform.isIOS
            ? "ios"
            : Platform.operatingSystem;
    final deviceNameLabel =
        Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : Platform.operatingSystem;

    setState(() => _loading = true);
    try {
      final inviteRaw = _inviteCtl.text.trim();
      final req = RegisterDeviceRequest(
        deviceId: session.deviceId,
        deviceName: deviceNameLabel,
        platform: platform,
        inviteCode: inviteRaw.isEmpty ? null : inviteRaw,
      );

      final base =
          ApiClient.normalizeServerInput(normalizedServer).trimRight().replaceAll(RegExp(r"/+$"), "");
      regDebugPrint("register_device_screen submit");
      regDebugPrint("final register url=$base/devices/register");

      final res = await scope.deviceService.register(req, normalizedServer);
      await session.applyRegistration(
        rawServerUrl: normalizedServer,
        newDeviceToken: res.deviceToken,
        stableDeviceId: res.deviceId.trim().isEmpty ? session.deviceId : res.deviceId,
        deviceName: deviceNameLabel,
      );
      regDebugPrint("token saved=true");
    } catch (e, st) {
      regDebugLogRegistrationFailure(e, st);
      final msg =
          e is ApiError ? localizedApiErrorMessage(l10n, e) : localizedApiErrorMessage(l10n, ApiError.fromUnknown(e));
      setState(() => _errorUx = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = AppScope.read(context).session;

    return DecoratedBox(
      decoration: linkClipPageGradientDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(l10n.registerTitle),
          actions: [
            languagePickerIconButton(context, session),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _loading ? null : _openSettings,
              tooltip: l10n.registerSettingsTooltip,
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.registerIntroHelper,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.registerSecureServerLine,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                if (_showInviteField) ...[
                  AppTextField(
                    controller: _inviteCtl,
                    label: l10n.registerInviteOptional,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _showInviteField = true;
                            }),
                    child: Text(l10n.registerHaveInviteCode),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_errorUx != null) ...[
                  Text(
                    _errorUx!,
                    style: TextStyle(color: scheme.error, height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 8),
                AppPrimaryButton(
                  label: l10n.registerSubmit,
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
