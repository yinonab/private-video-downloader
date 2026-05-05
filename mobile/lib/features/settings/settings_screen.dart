import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/device_models.dart";
import "../../core/network/api_client.dart";
import "../../core/widgets/branded_loading.dart";
import "../../core/widgets/language_picker.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = false;
  Object? _lastErr;
  DeviceMeResponse? _me;

  final _serverCtl = TextEditingController();
  bool _advBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMe());
  }

  @override
  void dispose() {
    _serverCtl.dispose();
    super.dispose();
  }

  void _syncServerField() {
    final s = AppScope.read(context).session;
    _serverCtl.text = s.serverUrl;
  }

  Future<void> _refreshMe() async {
    final scope = AppScope.read(context);
    _syncServerField();
    setState(() {
      _loading = true;
      _lastErr = null;
    });
    try {
      final me = await scope.deviceService.me();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastErr = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    final l10n = context.l10n;
    final session = AppScope.read(context).session;
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsFactoryResetTitle),
        content: Text(l10n.settingsFactoryResetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.homeCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.settingsFactoryResetConfirm)),
        ],
      ),
    );
    if (ok != true) return;
    await session.factoryResetLocal();
    if (!context.mounted) return;
    nav.popUntil((r) => r.isFirst);
  }

  Future<void> _applyCustomServer() async {
    final l10n = context.l10n;
    final scope = AppScope.read(context);
    final normalized = ApiClient.normalizeServerInput(_serverCtl.text.trim());
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsEnterServerSnack)));
      return;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsInvalidServerSnack)));
      return;
    }

    setState(() => _advBusy = true);
    try {
      await scope.session.setCustomServerEnabled(true, serverUrlRaw: normalized);
      await scope.session.clearRegistrationToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsServerUpdatedSnack)),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _advBusy = false);
    }
  }

  Future<void> _useBakedServerDefault() async {
    final l10n = context.l10n;
    final baked = kApiBaseUrlFromDefine.trim();
    if (baked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsNoBakedUrlSnack)),
      );
      return;
    }
    final scope = AppScope.read(context);
    setState(() => _advBusy = true);
    try {
      await scope.session.setCustomServerEnabled(false);
      await scope.session.clearRegistrationToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsRevertSnack)),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _advBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = AppScope.read(context).session;
    final me = _me;
    final baked = kApiBaseUrlFromDefine.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: RefreshIndicator(
        onRefresh: _refreshMe,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.languageSectionTitle),
              trailing: TextButton(
                onPressed: () => showAppLanguagePicker(context, s),
                child: Text(l10n.languageSelectButton),
              ),
            ),
            const Divider(height: 24),
            Text(l10n.settingsServerUrl, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(s.serverUrl.isEmpty ? l10n.settingsEmptyPlaceholder : s.serverUrl, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            Text(l10n.settingsDeviceId, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(s.deviceId.isEmpty ? "—" : s.deviceId),
            const SizedBox(height: 22),
            Row(
              children: [
                FilledButton.tonal(onPressed: _loading ? null : _refreshMe, child: Text(l10n.settingsRefreshDevice)),
                if (_loading) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: BrandedLoadingMark(size: 22),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            if (_lastErr != null)
              Text(
                _lastErr is ApiError ? localizedApiErrorMessage(l10n, _lastErr! as ApiError) : l10n.homeErrorGeneric,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (me != null) ...[
              const Divider(height: 32),
              Text("${l10n.settingsMeStatusLabel}: ${me.status.isEmpty ? "—" : me.status}"),
              if ((me.name ?? "").trim().isNotEmpty) Text("${l10n.settingsMeNameLabel}: ${me.name}"),
              Text("${l10n.settingsMeDailyDownloadsLabel}: ${me.dailyLimit <= 0 ? "—" : "${me.dailyLimit}"}"),
              Text("${l10n.settingsMeDailyAnalyzeLabel}: ${me.analyzeDailyLimit <= 0 ? "—" : "${me.analyzeDailyLimit}"}"),
            ],
            const Divider(height: 32),
            ExpansionTile(
              title: Text(l10n.settingsAdvancedDevelopers),
              subtitle: Text(s.usesCustomServerUrl ? l10n.settingsAdvancedCustomSubtitle : l10n.settingsAdvancedDefaultSubtitle),
              children: [
                TextField(
                  controller: _serverCtl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsServerFieldLabel,
                    hintText: l10n.settingsServerFieldHint,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _advBusy ? null : _applyCustomServer,
                  child: Text(l10n.settingsSaveCustomServer),
                ),
                if (baked) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _advBusy ? null : _useBakedServerDefault,
                    child: Text(l10n.settingsRevertToBakedServer),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.settingsAdvancedFooterNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 44),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
              onPressed: _reset,
              child: Text(l10n.settingsFactoryResetConfirm, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
