import "../core/models/device_models.dart";
import "../core/network/api_client.dart";

final class DeviceService {
  DeviceService(this._api);
  final ApiClient _api;

  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req, String serverInput) async {
    final normalized = ApiClient.normalizeServerInput(serverInput);
    return _api.register(req, normalized);
  }

  Future<DeviceMeResponse> me() => _api.deviceMe();
}
