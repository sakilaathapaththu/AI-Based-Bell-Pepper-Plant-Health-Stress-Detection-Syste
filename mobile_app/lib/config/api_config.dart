/// Base URL + endpoint paths for the unified backend
/// (unified-backend/app/main.py).
///
/// baseUrl is the ngrok forwarding URL for the backend while it's running
/// locally - update it here each time a new ngrok tunnel is started (free
/// ngrok URLs change on every restart).
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = 'https://ff72-2402-d000-8110-555b-e9fa-55d7-656d-b165.ngrok-free.app';

  static const String health = '/health';

  static const String rgbPredict = '/rgb/predict';
  static const String thermalPredict = '/thermal/predict';
  static const String environmentalCheck = '/environmental/check-environment';
  static const String environmentalPredict = '/environmental/predict';
  static const String adaptiveRecoveryPlan = '/adaptive/generate-recovery-plan';
  static const String analyze = '/analyze';
}
