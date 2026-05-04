class RegisterDeviceRequest {
  RegisterDeviceRequest({
    required this.deviceId,
    this.deviceName,
    required this.platform,
    this.inviteCode,
  });

  Map<String, dynamic> toJson() => {
        "deviceId": deviceId,
        if (deviceName != null && deviceName!.trim().isNotEmpty) "deviceName": deviceName!.trim(),
        "platform": platform,
        if (inviteCode != null && inviteCode!.trim().isNotEmpty) "inviteCode": inviteCode!.trim(),
      };

  final String deviceId;
  final String? deviceName;
  final String platform;
  final String? inviteCode;
}

class RegisterDeviceResponse {
  RegisterDeviceResponse({required this.deviceId, required this.deviceToken, required this.status});

  factory RegisterDeviceResponse.fromJson(Map<String, dynamic>? j) {
    final map = Map<String, dynamic>.from(j ?? {});
    return RegisterDeviceResponse(
      deviceId: "${map["deviceId"] ?? ""}",
      deviceToken: "${map["deviceToken"] ?? ""}",
      status: "${map["status"] ?? ""}",
    );
  }

  final String deviceId;
  final String deviceToken;
  final String status;
}

class DeviceMeResponse {
  DeviceMeResponse({
    required this.deviceId,
    this.name,
    this.platform,
    required this.dailyLimit,
    required this.analyzeDailyLimit,
    required this.status,
    this.createdAt,
    this.lastSeenAt,
  });

  factory DeviceMeResponse.fromJson(Map<String, dynamic>? j) {
    final map = Map<String, dynamic>.from(j ?? {});
    int toInt(dynamic v) {
      if (v is num) return v.round();
      return int.tryParse("$v") ?? 0;
    }

    return DeviceMeResponse(
      deviceId: "${map["deviceId"] ?? ""}",
      name: map["name"]?.toString(),
      platform: map["platform"]?.toString(),
      dailyLimit: toInt(map["dailyLimit"]),
      analyzeDailyLimit: toInt(map["analyzeDailyLimit"]),
      status: "${map["status"] ?? ""}",
      createdAt: map["createdAt"]?.toString(),
      lastSeenAt: map["lastSeenAt"]?.toString(),
    );
  }

  final String deviceId;
  final String? name;
  final String? platform;

  /// Per-device downloads/day (backend [dailyLimit]).
  final int dailyLimit;

  /// Server-enforced analyze cap (optional field — 0 means unknown/old server).
  final int analyzeDailyLimit;
  final String status;
  final String? createdAt;
  final String? lastSeenAt;
}
