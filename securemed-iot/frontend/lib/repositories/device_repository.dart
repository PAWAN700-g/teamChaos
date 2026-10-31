import '../models/device_model.dart';
import '../services/api_service.dart';

class DeviceRepository {
  final ApiService _apiService;

  DeviceRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<List<DeviceModel>> fetchDevices() async {
    final rawList = await _apiService.getDevices();
    return rawList.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DeviceModel> getDevice(String deviceId) async {
    final data = await _apiService.getDevice(deviceId);
    return DeviceModel.fromJson(data);
  }

  Future<DeviceModel> registerDevice({
    required String deviceId,
    required String deviceType,
    required String dsaPublicKeyB64,
  }) async {
    final data = await _apiService.registerDevice(
      deviceId: deviceId,
      deviceType: deviceType,
      dsaPublicKeyB64: dsaPublicKeyB64,
    );
    return DeviceModel.fromJson(data);
  }

  Future<DeviceModel> revokeDevice(String deviceId, {String reason = "Admin emergency revocation"}) async {
    final data = await _apiService.revokeDevice(deviceId, reason: reason);
    return DeviceModel.fromJson(data);
  }
}
