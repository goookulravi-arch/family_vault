import 'package:flutter/material.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../authentication/views/change_pin_screen.dart';
import '../../authentication/views/pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();

  final BiometricService _biometricService = BiometricService();

  bool _isLoading = true;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isChangingBiometric = false;

  @override
  void initState() {
    super.initState();

    _loadSecuritySettings();
  }

  // ============================================================
  // LOAD SECURITY SETTINGS
  // ============================================================

  Future<void> _loadSecuritySettings() async {
    try {
      final appLockEnabled = await _secureStorage.isAppLockEnabled();

      final biometricAvailable = await _biometricService.isAvailable();

      final biometricEnabled = await _secureStorage.isBiometricEnabled();

      if (!mounted) return;

      setState(() {
        _appLockEnabled = appLockEnabled;
        _biometricAvailable = biometricAvailable;

        _biometricEnabled =
            appLockEnabled && biometricAvailable && biometricEnabled;

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _biometricAvailable = false;
        _biometricEnabled = false;
      });
    }
  }

  // ============================================================
  // ENABLE APP LOCK
  // ============================================================

  Future<void> _enableAppLock() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinSetupScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadSecuritySettings();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'App Lock enabled successfully.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DISABLE APP LOCK
  // ============================================================

  Future<void> _disableAppLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Disable App Lock?',
          ),
          content: const Text(
            'Your Family Vault will no longer '
            'require a PIN when opening the app.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Disable'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _secureStorage.disableAppLock();

    if (!mounted) return;

    setState(() {
      _appLockEnabled = false;
      _biometricEnabled = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'App Lock disabled.',
        ),
      ),
    );
  }

  // ============================================================
  // CHANGE PIN
  // ============================================================

  Future<void> _changePin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ChangePinScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PIN changed successfully.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // TOGGLE BIOMETRIC
  // ============================================================

  Future<void> _toggleBiometric(bool value) async {
    if (_isChangingBiometric) {
      return;
    }

    if (!_appLockEnabled) {
      return;
    }

    if (!_biometricAvailable) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric authentication is not available on this device.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isChangingBiometric = true;
    });

    try {
      // ==========================================================
      // ENABLE
      // ==========================================================

      if (value) {
        final authenticated = await _biometricService.authenticate();

        if (!mounted) return;

        if (!authenticated) {
          setState(() {
            _isChangingBiometric = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometric authentication was not completed.',
              ),
            ),
          );

          return;
        }

        // Save biometric preference.
        await _secureStorage.setBiometricEnabled(true);

        if (!mounted) return;

        setState(() {
          _biometricEnabled = true;
          _isChangingBiometric = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric Unlock enabled.',
            ),
          ),
        );

        return;
      }

      // ==========================================================
      // DISABLE
      // ==========================================================

      await _secureStorage.setBiometricEnabled(false);

      if (!mounted) return;

      setState(() {
        _biometricEnabled = false;
        _isChangingBiometric = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric Unlock disabled.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isChangingBiometric = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to change biometric settings.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SECURITY SECTION
  // ============================================================

  Widget _buildSecuritySection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // ======================================================
          // APP LOCK
          // ======================================================

          ListTile(
            leading: CircleAvatar(
              child: Icon(
                _appLockEnabled ? Icons.lock : Icons.lock_open,
              ),
            ),
            title: const Text(
              'App Lock',
            ),
            subtitle: Text(
              _appLockEnabled
                  ? 'Your vault is protected by a PIN'
                  : 'Protect your vault with a PIN',
            ),
            trailing: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Switch(
                    value: _appLockEnabled,
                    onChanged: (value) {
                      if (value) {
                        _enableAppLock();
                      } else {
                        _disableAppLock();
                      }
                    },
                  ),
          ),

          // ======================================================
          // CHANGE PIN
          // ======================================================

          if (_appLockEnabled)
            const Divider(
              height: 1,
            ),

          if (_appLockEnabled)
            ListTile(
              leading: const Icon(
                Icons.password,
              ),
              title: const Text(
                'Change PIN',
              ),
              subtitle: const Text(
                'Create a new vault PIN',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: _changePin,
            ),

          // ======================================================
          // BIOMETRIC
          // ======================================================

          if (_appLockEnabled && _biometricAvailable)
            const Divider(
              height: 1,
            ),

          if (_appLockEnabled && _biometricAvailable)
            ListTile(
              leading: const Icon(
                Icons.fingerprint,
              ),
              title: const Text(
                'Biometric Unlock',
              ),
              subtitle: const Text(
                'Use fingerprint or face authentication',
              ),
              trailing: _isChangingBiometric
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Switch(
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Security',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          _buildSecuritySection(),
          const SizedBox(
            height: 24,
          ),
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.family_restroom,
                  ),
                  title: Text(
                    'Family Vault',
                  ),
                  subtitle: Text(
                    'Private family information '
                    'and document manager',
                  ),
                ),
                const Divider(
                  height: 1,
                ),
                const ListTile(
                  leading: Icon(
                    Icons.info_outline,
                  ),
                  title: Text(
                    'Version',
                  ),
                  trailing: Text(
                    '1.0.0',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
