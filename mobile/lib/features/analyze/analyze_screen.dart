import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/operation_wakelock.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../core/models/analyze_models.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/utils/video_title_split.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/error_view.dart";
import "widgets/analyze_processing_animation.dart";
import "../../core/widgets/expandable_description.dart";
import "../../core/widgets/linkclip_network_thumbnail.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../core/widgets/linkclip_chips.dart";
import "../download_status/download_status_screen.dart";
import "quality_selector.dart";

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key, required this.initialUrl});

  final String initialUrl;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  AnalyzeResponse? _data;
  ApiError? _err;
  bool _loading = true;
  int _fmtIndex = 0;
  bool _analyzeWakelockHeld = false;

  Future<void> _setAnalyzeWakelock(bool want) async {
    if (want == _analyzeWakelockHeld) return;
    if (want) {
      await OperationWakelock.acquire();
      _analyzeWakelockHeld = true;
    } else {
      await OperationWakelock.release();
      _analyzeWakelockHeld = false;
    }
  }

  @override
  void dispose() {
    unawaited(_setAnalyzeWakelock(false));
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void didUpdateWidget(covariant AnalyzeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialUrl != widget.initialUrl) {
      shareDebugPrint("Analyze initialUrl replaced, re-running analyze");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  Future<void> _run() async {
    final u = widget.initialUrl.trim();
    if (u.isEmpty) {
      setState(() {
        _loading = false;
        _err = ApiError(code: "MISSING_LINK", message: "empty");
      });
      return;
    }
    shareDebugPrint("auto analyze triggered url=$u");
    await _setAnalyzeWakelock(true);
    if (!mounted) {
      await _setAnalyzeWakelock(false);
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final svc = AppScope.read(context).analyzeService;
      final res = await svc.analyze(u);
      if (!mounted) return;
      setState(() {
        _data = res;
        _fmtIndex = res.pickDefaultFormatIndex();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e is ApiError ? e : ApiError.fromUnknown(e));
    } finally {
      if (mounted) setState(() => _loading = false);
      await _setAnalyzeWakelock(false);
    }
  }

  void _startDownload() {
    final l10n = context.l10n;
    final d = _data;
    if (d == null) return;
    final fmtList = d.availableFormats;
    if (fmtList.isEmpty) return;
    final idx = FormatOption.clampSelectableIndex(fmtList, _fmtIndex);
    final fmt = fmtList[idx];
    if (!fmt.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analyzeQualityUnavailableSnack)),
      );
      return;
    }
    final req = CreateDownloadRequest(url: d.url, format: fmt.value, quality: fmt.value);
    downloadDebugPrint("Navigate pending download screen; POST /downloads will run there body=${req.toJson()}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadStatusScreen.pendingCreate(request: req),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: linkClipPageGradientDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LinkClipPremiumAppBar(title: Text(l10n.analyzeTitle)),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          AnalyzeProcessingAnimation(
            title: l10n.loadingAnalyzingDot,
            subtitle: l10n.analyzeProcessingSubtitle,
          ),
          KeepAppOpenHint(l10n.keepAppOpenUntilAnalyzeFinished),
        ],
      );
    }
    if (_err != null) {
      final detail = localizedApiErrorDetail(l10n, _err!);
      return ErrorView(
        title: detail.title,
        subtitle: detail.body,
        retryLabel: l10n.bootstrapRetry,
        onRetry: _run,
      );
    }
    final d = _data;
    if (d == null) return const SizedBox.shrink();

    final dur = d.durationSec;
    String? durText;
    if (dur != null && dur > 0) {
      final h = dur ~/ 3600;
      final m = (dur % 3600) ~/ 60;
      final s = dur % 60;
      durText = h > 0
          ? "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}"
          : "$m:${s.toString().padLeft(2, '0')}";
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;
    final dark = theme.brightness == Brightness.dark;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.analyzeVideoFound,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: dark ? const <BoxShadow>[] : palette.cardShadows,
          ),
          child: Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: scheme.outline.withValues(alpha: dark ? 0.55 : 0.4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: d.thumbnail != null && d.thumbnail!.isNotEmpty
                          ? LinkClipNetworkThumbnail(
                              imageUrl: d.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _mediaPlaceholder(),
                            )
                          : _mediaPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (context) {
                      final split = splitVideoTitleForDisplay(d.title);
                      final headline =
                          split.headlineTitle.trim().isEmpty ? l10n.untitledVideo : split.headlineTitle.trim();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            headline,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          if (split.expandableDescription != null &&
                              split.expandableDescription!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ExpandableDescription(text: split.expandableDescription!.trim()),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      LinkClipPlatformChip(label: d.platform),
                      if (durText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: scheme.outline.withValues(alpha: 0.28)),
                          ),
                          child: Text(
                            l10n.analyzeDurationLabel(durText),
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        QualitySelector(
          formats: d.availableFormats,
          selectedIndex: FormatOption.clampSelectableIndex(d.availableFormats, _fmtIndex),
          onChanged: (i) => setState(() => _fmtIndex = i),
        ),
        const SizedBox(height: 26),
        AppPrimaryButton(label: l10n.analyzePrepareDownload, loading: false, onPressed: _startDownload),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: column
          .animate()
          .fadeIn(duration: 280.ms, curve: Curves.easeOut)
          .slideY(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
    );
  }

  Widget _mediaPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(child: Icon(LucideIcons.video, size: 64, color: scheme.onSurfaceVariant)),
    );
  }
}
