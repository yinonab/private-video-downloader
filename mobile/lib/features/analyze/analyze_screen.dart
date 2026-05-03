import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/models/analyze_models.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/error_view.dart";
import "../../core/widgets/loading_view.dart";
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

  Future<void> _run() async {
    final u = widget.initialUrl.trim();
    if (u.isEmpty) {
      setState(() {
        _loading = false;
        _err = ApiError(code: "BAD_REQUEST", message: "empty", hebrewSummary: "חסר קישור");
      });
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
      setState(() => _data = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e is ApiError ? e : ApiError.fromUnknown(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startDownload() async {
    final d = _data;
    if (d == null) return;
    final fmtList = d.availableFormats;
    if (fmtList.isEmpty) return;
    final fmt = fmtList[_fmtIndex.clamp(0, fmtList.length - 1)];
    setState(() => _starting = true);
    final scope = AppScope.read(context);
    final svc = scope.downloadService;
    final req = CreateDownloadRequest(url: d.url, format: fmt.value, quality: fmt.value);
    final base = scope.session.serverUrl.trim().replaceAll(RegExp(r"/+$"), "");
    debugPrint("### DOWNLOAD_DEBUG ### POST /downloads request url=$base/downloads body=${req.toJson()}");
    try {
      final res = await svc.create(req);
      debugPrint("### DOWNLOAD_DEBUG ### POST /downloads response selectedJobId=${res.jobId} status=${res.status} cached=${res.cached}");
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DownloadStatusScreen(jobId: res.jobId)),
      );
    } catch (e, st) {
      debugPrint("### DOWNLOAD_DEBUG ### catch analyze_screen._startDownload type=${e.runtimeType} message=$e");
      if (e is DioException) {
        debugPrint(
          "### DOWNLOAD_DEBUG ### DioException dioType=${e.type} responseStatus=${e.response?.statusCode} "
          "cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
        );
      }
      if (e is ApiError) {
        debugPrint(
          "### DOWNLOAD_DEBUG ### ApiError code=${e.code} httpStatus=${e.httpStatus} localized=${e.localized}",
        );
        const unexpectedHebrew = "אירעה שגיאה לא צפויה";
        if (e.localized == unexpectedHebrew ||
            (e.hebrewSummary != null && e.hebrewSummary == unexpectedHebrew)) {
          debugPrint(
            "### DOWNLOAD_DEBUG ### causes-localized-unexpected-error "
            "message=${e.message} details=${e.details}",
          );
        }
      }
      debugPrint("### DOWNLOAD_DEBUG ### stackTrace=\n$st");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiError ? e.localized : "$e")));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ניתוח קישור")),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(message: "מנתח קישור…");
    if (_err != null) {
      return ErrorView(title: _err!.localized, retryLabel: "נסה שוב", onRetry: _run);
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("נמצא סרטון", style: Theme.of(context).textTheme.headlineSmall),
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
            Text(d.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(d.platform)),
                if (durText != null) Chip(label: Text("משך $durText")),
              ],
            ),
            const SizedBox(height: 22),
            QualitySelector(
              formats: d.availableFormats,
              selectedIndex: _fmtIndex.clamp(0, d.availableFormats.length - 1),
              onChanged: (i) => setState(() => _fmtIndex = i),
            ),
            const SizedBox(height: 26),
            AppPrimaryButton(label: "התחל הורדה", loading: _starting, onPressed: _starting ? null : _startDownload),
          ],
        ),
      ),
    );
  }

  Widget _mediaPlaceholder() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.movie_filter_rounded, size: 64)),
    );
  }
}
