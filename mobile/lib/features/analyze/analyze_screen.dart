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
import "../../core/theme/linkclip_design_system.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/utils/download_perf_log.dart";
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
    final httpSw = Stopwatch()..start();
    try {
      final svc = AppScope.read(context).analyzeService;
      final res = await svc.analyze(u);
      httpSw.stop();
      if (!mounted) return;
      final uiSw = Stopwatch()..start();
      setState(() {
        _data = res;
        _fmtIndex = res.pickDefaultFormatIndex();
      });
      uiSw.stop();
      final thumb = res.thumbnail?.trim() ?? "";
      final qualityCount = res.availableFormats.length;
      logMobileDownloadPerf(
        stage: "analyze_http",
        durationMs: httpSw.elapsedMilliseconds,
        platform: res.platform,
        formatCount: qualityCount,
        qualityCount: qualityCount,
        thumbnailPresent: thumb.isNotEmpty,
        cacheHit: false,
        result: "success",
      );
      logMobileDownloadPerf(
        stage: "analyze_ui_ready",
        durationMs: uiSw.elapsedMilliseconds,
        platform: res.platform,
        result: "quality_selector_ready",
      );
    } catch (e) {
      httpSw.stop();
      if (!mounted) return;
      final err = e is ApiError ? e : ApiError.fromUnknown(e);
      setState(() => _err = err);
      logMobileDownloadPerf(
        stage: "analyze_http",
        durationMs: httpSw.elapsedMilliseconds,
        cacheHit: false,
        result: "failure",
      );
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
    final req =
        CreateDownloadRequest(url: d.url, format: fmt.value, quality: fmt.value);
    downloadDebugPrint(
        "Navigate pending download screen; POST /downloads will run there body=${req.toJson()}");
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
        padding: const EdgeInsets.symmetric(vertical: LcSpace.sm),
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
    final split = splitVideoTitleForDisplay(d.title);
    final headline = split.headlineTitle.trim().isEmpty
        ? l10n.untitledVideo
        : split.headlineTitle.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewH = (constraints.maxHeight * 0.36).clamp(220.0, 340.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LcSpace.lg,
            LcSpace.sm,
            LcSpace.lg,
            LcSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.analyzeVideoFound,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: LcSpace.md),
              LinkClipMediaPreviewCard(
                height: previewH,
                child: d.thumbnail != null && d.thumbnail!.isNotEmpty
                    ? LinkClipNetworkThumbnail(
                        imageUrl: d.thumbnail!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _mediaPlaceholder(),
                      )
                    : _mediaPlaceholder(),
              ),
              const SizedBox(height: LcSpace.lg),
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
              ),
              if (split.expandableDescription != null &&
                  split.expandableDescription!.trim().isNotEmpty) ...[
                const SizedBox(height: LcSpace.sm),
                ExpandableDescription(
                    text: split.expandableDescription!.trim()),
              ],
              const SizedBox(height: LcSpace.md),
              Wrap(
                spacing: LcSpace.sm,
                runSpacing: LcSpace.sm,
                children: [
                  LinkClipPlatformChip(label: d.platform),
                  if (durText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LcSpace.md,
                        vertical: LcSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        l10n.analyzeDurationLabel(durText),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: LcSpace.xl),
              QualitySelector(
                formats: d.availableFormats,
                selectedIndex: FormatOption.clampSelectableIndex(
                    d.availableFormats, _fmtIndex),
                onChanged: (i) => setState(() => _fmtIndex = i),
              ),
              const SizedBox(height: LcSpace.xl),
              AppPrimaryButton(
                label: l10n.analyzePrepareDownload,
                loading: false,
                onPressed: _startDownload,
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 260.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.03, end: 0, duration: 280.ms, curve: Curves.easeOut),
        );
      },
    );
  }

  Widget _mediaPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(LucideIcons.video, size: 64, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
