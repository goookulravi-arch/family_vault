import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricSettingsService {
  static const String _biometricEnabledKey = 'biometric_unlock_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isEnabled() async {
    final value = await _storage.read(
      key: _biometricEnabledKey,
    );

    return value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<void> disable() async {
    await _storage.delete(
      key: _biometricEnabledKey,
    );
  }
}
