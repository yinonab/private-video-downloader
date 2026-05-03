import "../core/models/analyze_models.dart";
import "../core/network/api_client.dart";

final class AnalyzeService {
  AnalyzeService(this._api);
  final ApiClient _api;

  Future<AnalyzeResponse> analyze(String url) => _api.analyze(url);
}
