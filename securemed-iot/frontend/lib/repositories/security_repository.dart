import '../models/simulation_result_model.dart';
import '../services/api_service.dart';

class SecurityRepository {
  final ApiService _apiService;

  SecurityRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<SimulationResultModel> runReplayAttackSimulation() async {
    final data = await _apiService.simulateReplay();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runTamperingSimulation() async {
    final data = await _apiService.simulateTampering();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runFakeDeviceSimulation() async {
    final data = await _apiService.simulateFakeDevice();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runUnauthorizedCommandSimulation() async {
    final data = await _apiService.simulateUnauthorizedCommand();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runFirmwareTamperingSimulation() async {
    final data = await _apiService.simulateFirmwareTampering();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runRateLimitSimulation() async {
    final data = await _apiService.simulateRateLimit();
    return SimulationResultModel.fromJson(data);
  }
}
