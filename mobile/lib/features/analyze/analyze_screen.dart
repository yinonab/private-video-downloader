import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/analyze_models.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/error_view.dart";
import "../../core/widgets/branded_loading.dart";
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
  bool _starting = false;
  int _fmtIndex = 0;

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
    }
  }

  Future<void> _startDownload() async {
    final l10n = context.l10n;
    final d = _data;
    if (d == null) return;
    final fmtList = d.availableFormats;
    if (fmtList.isEmpty) return;
    final idx = FormatOption.clampSelectableIndex(fmtList, _fmtIndex);
    final fmt = fmtList[idx];
    if (!fmt.available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analyzeQualityUnavailableSnack)),
      );
      return;
    }
    setState(() => _starting = true);
    final scope = AppScope.read(context);
    final svc = scope.downloadService;
    final req = CreateDownloadRequest(url: d.url, format: fmt.value, quality: fmt.value);
    final base = scope.session.serverUrl.trim().replaceAll(RegExp(r"/+$"), "");
    downloadDebugPrint("POST /downloads request url=$base/downloads body=${req.toJson()}");
    try {
      final res = await svc.create(req);
      downloadDebugPrint(
        "POST /downloads response selectedJobId=${res.jobId} status=${res.status} cached=${res.cached}",
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DownloadStatusScreen(jobId: res.jobId)),
      );
    } catch (e, st) {
      downloadDebugPrint("catch analyze_screen._startDownload type=${e.runtimeType} message=$e");
      if (e is DioException) {
        downloadDebugPrint(
          "DioException dioType=${e.type} responseStatus=${e.response?.statusCode} "
          "cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
        );
      }
      if (e is ApiError) {
        downloadDebugPrint(
          "ApiError code=${e.code} httpStatus=${e.httpStatus} localized=${e.localized}",
        );
      }
      downloadDebugStackTrace("analyze_screen._startDownload", st);
      if (!mounted) return;
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : "$e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.analyzeTitle)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) return BrandedLoadingPanel(message: l10n.loadingAnalyzingDot);
    if (_err != null) {
      return ErrorView(
        title: localizedApiErrorMessage(l10n, _err!),
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

    final titleLine = d.title.trim().isEmpty ? l10n.untitledVideo : d.title;

    final column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.analyzeVideoFound, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: d.thumbnail != null && d.thumbnail!.isNotEmpty
                  ? Image.network(
                      d.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _mediaPlaceholder(),
                    )
                  : _mediaPlaceholder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(titleLine, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(d.platform)),
              if (durText != null) Chip(label: Text(l10n.analyzeDurationLabel(durText))),
            ],
          ),
          const SizedBox(height: 22),
          QualitySelector(
            formats: d.availableFormats,
            selectedIndex: FormatOption.clampSelectableIndex(d.availableFormats, _fmtIndex),
            onChanged: (i) => setState(() => _fmtIndex = i),
          ),
          const SizedBox(height: 26),
          AppPrimaryButton(label: l10n.analyzePrepareDownload, loading: _starting, onPressed: _starting ? null : _startDownload),
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
