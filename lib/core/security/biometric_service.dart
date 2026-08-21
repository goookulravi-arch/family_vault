import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // ============================================================
  // CHECK BIOMETRIC AVAILABILITY
  // ============================================================

  Future<bool> isAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();

      if (!isSupported) {
        return false;
      }

      final biometrics = await _auth.getAvailableBiometrics();

      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // GET AVAILABLE BIOMETRICS
  // ============================================================

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // AUTHENTICATE
  // ============================================================

  Future<bool> authenticate() async {
    try {
      final available = await isAvailable();

      if (!available) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock Family Vault.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
