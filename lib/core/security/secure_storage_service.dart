import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _pinKey = 'family_vault_pin';
  static const String _appLockEnabledKey = 'family_vault_app_lock_enabled';
  static const String _biometricEnabledKey = 'family_vault_biometric_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ============================================================
  // PIN
  // ============================================================

  Future<void> savePin(String pin) async {
    await _storage.write(
      key: _pinKey,
      value: pin,
    );
  }

  Future<String?> getPin() async {
    return _storage.read(
      key: _pinKey,
    );
  }

  Future<bool> hasPin() async {
    final pin = await getPin();

    return pin != null && pin.isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await getPin();

    if (savedPin == null || savedPin.isEmpty) {
      return false;
    }

    return savedPin == pin;
  }

  Future<void> deletePin() async {
    await _storage.delete(
      key: _pinKey,
    );
  }

  // ============================================================
  // APP LOCK
  // ============================================================

  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(
      key: _appLockEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> isAppLockEnabled() async {
    final value = await _storage.read(
      key: _appLockEnabledKey,
    );

    return value == 'true';
  }

  Future<void> disableAppLock() async {
    await _storage.write(
      key: _appLockEnabledKey,
      value: 'false',
    );

    // If App Lock is disabled, biometric unlock
    // should also be disabled.
    await setBiometricEnabled(false);
  }

  // ============================================================
  // BIOMETRIC
  // ============================================================

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(
      key: _biometricEnabledKey,
    );

    return value == 'true';
  }

  Future<void> disableBiometric() async {
    await setBiometricEnabled(false);
  }

  // ============================================================
  // CLEAR SECURITY DATA
  // ============================================================

  Future<void> clearSecurityData() async {
    await _storage.delete(
      key: _pinKey,
    );

    await _storage.delete(
      key: _appLockEnabledKey,
    );

    await _storage.delete(
      key: _biometricEnabledKey,
    );
  }
}
