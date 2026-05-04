import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/models/api_error.dart";
import "../../core/models/device_models.dart";
import "../../core/network/api_client.dart";

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("איפוס אפליקציה"),
        content: const Text("פעולה זו תמחק את ההתחברות וההיסטוריה המקומית שמורים במכשיר."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ביטול")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("איפוס")),
        ],
      ),
    );
    if (ok != true) return;
    await AppScope.read(context).session.factoryResetLocal();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _applyCustomServer() async {
    final scope = AppScope.read(context);
    final normalized = ApiClient.normalizeServerInput(_serverCtl.text.trim());
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("נא להזין כתובת שרת")));
      return;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("כתובת השרת לא תקינה")));
      return;
    }

    setState(() => _advBusy = true);
    try {
      await scope.session.setCustomServerEnabled(true, serverUrlRaw: normalized);
      await scope.session.clearRegistrationToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("השרת עודכן. מתבצע רישום מחדש אוטומטית.")),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _advBusy = false);
    }
  }

  Future<void> _useBakedServerDefault() async {
    final baked = kApiBaseUrlFromDefine.trim();
    if (baked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("אין כתובת שרת מוטמעת בגרסה זו")),
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
        const SnackBar(content: Text("חוזרים לשרת המוגדר בגרסת האפליקציה")),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _advBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context).session;
    final me = _me;
    final baked = kApiBaseUrlFromDefine.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("הגדרות")),
      body: RefreshIndicator(
        onRefresh: _refreshMe,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("כתובת שרת", style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(s.serverUrl.isEmpty ? "(ריק)" : s.serverUrl, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 22),
                  Text("מזהה מכשיר", style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SelectableText(s.deviceId.isEmpty ? "—" : s.deviceId),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      FilledButton.tonal(onPressed: _loading ? null : _refreshMe, child: const Text("רענון נתוני מכשיר")),
                      if (_loading) ...[const SizedBox(width: 12), const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))],
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (_lastErr != null)
                    Text(
                      _lastErr is ApiError ? (_lastErr! as ApiError).localized : "שגיאה",
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (me != null) ...[
                    const Divider(height: 32),
                    Text("סטטוס במערכת: ${me.status.isEmpty ? "—" : me.status}"),
                    if ((me.name ?? "").trim().isNotEmpty) Text("שם במערכת: ${me.name}"),
                    Text("מגבלת הורדות יומית: ${me.dailyLimit <= 0 ? "לא ידוע" : "${me.dailyLimit}"}"),
                    Text("מגבלת ניתוח יומית: ${me.analyzeDailyLimit <= 0 ? "לא הוגדר" : "${me.analyzeDailyLimit}"}"),
                  ],
                  const Divider(height: 32),
                  ExpansionTile(
                    title: const Text("מתקדם / מפתחים"),
                    subtitle: Text(s.usesCustomServerUrl ? "שרת מותאם אישית" : "שרת ברירת מחדל מהאפליקציה"),
                    children: [
                      TextField(
                        controller: _serverCtl,
                        decoration: const InputDecoration(
                          labelText: "כתובת שרת (LAN / בדיקות)",
                          hintText: "https://… או http://192.168.x.x:3000",
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _advBusy ? null : _applyCustomServer,
                        child: const Text("שמור שרת מותאם והתחבר מחדש"),
                      ),
                      if (baked) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _advBusy ? null : _useBakedServerDefault,
                          child: const Text("חזרה לשרת המוגדר בגרסת האפליקציה"),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        "גרסת ייצור רגילה משתמשת בכתובת המוטמעת ב־APK. כאן רק לפיתוח או שרת זמני.",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
                    onPressed: _reset,
                    child: Text("איפוס והזנה מחדש", style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
