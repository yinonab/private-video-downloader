import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/device_models.dart";
import "../../core/network/api_client.dart";
import "../../core/storage/local_session.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/utils/url_utils.dart";
import "../../core/widgets/branded_loading.dart";
import "../../core/widgets/language_picker.dart";
import "../../core/widgets/linkclip_app_bar.dart";

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
    _serverCtl.text = s.effectiveApiBaseUrl;
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
    final trimmed = _serverCtl.text.trim();

    if (trimmed.isEmpty) {
      setState(() => _advBusy = true);
      try {
        await scope.session.setCustomServerEnabled(false);
        await scope.session.clearRegistrationToken();
        if (!mounted) return;
        _syncServerField();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsRevertSnack)),
        );
        Navigator.of(context).pop();
      } finally {
        if (mounted) setState(() => _advBusy = false);
      }
      return;
    }

    final normalized = ApiClient.normalizeServerInput(trimmed);
    if (!UrlUtils.looksLikeHttpUrl(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorServerUrlInvalidConfig)),
      );
      return;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorServerUrlInvalidConfig)),
      );
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

  Future<void> _useBundledDefaultServer() async {
    final l10n = context.l10n;
    final scope = AppScope.read(context);
    setState(() => _advBusy = true);
    try {
      await scope.session.setCustomServerEnabled(false);
      await scope.session.clearRegistrationToken();
      if (!mounted) return;
      _syncServerField();
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
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    Widget panel(Widget child) => DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: dark ? 0.38 : 0.42)),
          ),
          child: child,
        );

    return DecoratedBox(
      decoration: linkClipPageGradientDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LinkClipPremiumAppBar(title: Text(l10n.settingsTitle)),
        body: RefreshIndicator(
          onRefresh: _refreshMe,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              panel(
                ListTile(
                  contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                  leading: Icon(Icons.language_outlined, color: scheme.onSurfaceVariant.withValues(alpha: 0.88), size: 22),
                  title: Text(
                    l10n.settingsLanguageRowTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    s.locale.languageCode == "he" ? l10n.languageHebrewOption : l10n.languageEnglish,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onTap: () => showAppLanguagePicker(context, s),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.appearance,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              panel(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final mode in ThemePreference.values)
                        RadioListTile<ThemePreference>(
                          value: mode,
                          groupValue: s.themePreference,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          onChanged: (v) async {
                            if (v == null) return;
                            await s.setThemePreference(v);
                            if (mounted) setState(() {});
                          },
                          title: Text(
                            switch (mode) {
                              ThemePreference.system => l10n.themeSystem,
                              ThemePreference.light => l10n.themeLight,
                              ThemePreference.dark => l10n.themeDark,
                            },
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.settingsServerUrl,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              panel(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        s.effectiveApiBaseUrl,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.92)),
                      ),
                      if (!s.usesCustomServerUrl) ...[
                        const SizedBox(height: 8),
                        Text(
                          kApiBaseUrlFromDefine.trim().isNotEmpty ? l10n.settingsBundledFromBuildSubtitle : l10n.settingsBundledProductionSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.settingsDeviceId,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              panel(
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, top: 8, bottom: 8, end: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        s.deviceId.isEmpty ? "—" : s.deviceId,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                              onPressed: _loading ? null : _refreshMe,
                              child: Text(l10n.settingsRefreshDevice),
                            ),
                            if (_loading) SizedBox(width: 24, height: 24, child: BrandedLoadingMark(size: 20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_lastErr != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _lastErr is ApiError ? localizedApiErrorMessage(l10n, _lastErr! as ApiError) : l10n.homeErrorGeneric,
                    style: TextStyle(color: scheme.error.withValues(alpha: 0.92), height: 1.35),
                  ),
                ),
              if (me != null)
                panel(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "${l10n.settingsMeStatusLabel}: ${me.status.isEmpty ? "—" : me.status}",
                          style: theme.textTheme.bodyMedium,
                        ),
                        if ((me.name ?? "").trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text("${l10n.settingsMeNameLabel}: ${me.name}", style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          "${l10n.settingsMeDailyDownloadsLabel}: ${me.dailyLimit <= 0 ? "—" : "${me.dailyLimit}"}",
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${l10n.settingsMeDailyAnalyzeLabel}: ${me.analyzeDailyLimit <= 0 ? "—" : "${me.analyzeDailyLimit}"}",
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              if (me != null) const SizedBox(height: 18),
              Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.35 : 0.55),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    collapsedShape:
                        const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    title: Text(l10n.settingsAdvancedDevelopers, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      s.usesCustomServerUrl ? l10n.settingsAdvancedCustomSubtitle : l10n.settingsAdvancedDefaultSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    iconColor: scheme.onSurfaceVariant,
                    collapsedIconColor: scheme.onSurfaceVariant,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: dark ? 0.35 : 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outline.withValues(alpha: dark ? 0.35 : 0.42)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: scheme.primary.withValues(alpha: 0.85),
                                  foregroundColor: scheme.onPrimary,
                                ),
                                onPressed: _advBusy ? null : _applyCustomServer,
                                child: Text(l10n.settingsSaveCustomServer),
                              ),
                              if (s.usesCustomServerUrl) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _advBusy ? null : _useBundledDefaultServer,
                                  child: Text(l10n.settingsRevertToBakedServer),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                l10n.settingsAdvancedFooterNote,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error.withValues(alpha: 0.92),
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.28)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _reset,
                child: Text(l10n.settingsFactoryResetConfirm, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
