import '../models/simulation_result_model.dart';
import '../services/api_service.dart';

class SecurityRepository {
  final ApiService _apiService;

  SecurityRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<SimulationResultModel> runDeviceImpersonationSimulation() async {
    final data = await _apiService.simulateDeviceImpersonation();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runReplayAttackSimulation() async {
    final data = await _apiService.simulateReplay();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runTamperingSimulation() async {
    final data = await _apiService.simulateTampering();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runFakeDeviceSimulation() => runDeviceImpersonationSimulation();

  Future<SimulationResultModel> runUnauthorizedAccessSimulation() async {
    final data = await _apiService.simulateUnauthorizedAccess();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runUnauthorizedCommandSimulation() => runUnauthorizedAccessSimulation();

  Future<SimulationResultModel> runFirmwareTamperingSimulation() async {
    final data = await _apiService.simulateFirmwareTampering();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runRateLimitSimulation() async {
    final data = await _apiService.simulateRateLimit();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runDeviceRevocationSimulation() async {
    final data = await _apiService.simulateDeviceRevocation();
    return SimulationResultModel.fromJson(data);
  }

  Future<SimulationResultModel> runAuditModificationSimulation() async {
    final data = await _apiService.simulateAuditModification();
    return SimulationResultModel.fromJson(data);
  }
}
