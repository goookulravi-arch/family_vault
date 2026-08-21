import 'package:flutter/material.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/security/secure_storage_service.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();

  final BiometricService _biometricService = BiometricService();

  final TextEditingController _pinController = TextEditingController();

  final FocusNode _pinFocusNode = FocusNode();

  bool _hidePin = true;
  bool _isChecking = false;
  bool _isBiometricChecking = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _checkBiometricAvailability();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // CHECK BIOMETRIC
  // ============================================================

  Future<void> _checkBiometricAvailability() async {
    try {
      final enabled = await _secureStorage.isBiometricEnabled();

      if (!mounted) return;

      if (!enabled) {
        setState(() {
          _biometricEnabled = false;
          _biometricAvailable = false;
        });

        return;
      }

      final available = await _biometricService.isAvailable();

      if (!mounted) return;

      setState(() {
        _biometricEnabled = enabled;
        _biometricAvailable = available;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _biometricEnabled = false;
        _biometricAvailable = false;
      });
    }
  }

  // ============================================================
  // VERIFY PIN
  // ============================================================

  Future<void> _verifyPin() async {
    if (_isChecking || _isBiometricChecking) {
      return;
    }

    FocusScope.of(context).unfocus();

    final pin = _pinController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your PIN.';
      });

      return;
    }

    if (pin.length < 4 || pin.length > 6) {
      setState(() {
        _errorMessage = 'PIN must contain 4 to 6 digits.';
      });

      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN can contain numbers only.';
      });

      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      final isCorrect = await _secureStorage.verifyPin(pin);

      if (!mounted) return;

      if (isCorrect) {
        // IMPORTANT:
        // Tell main.dart that authentication
        // was successful.
        widget.onUnlocked();

        return;
      }

      _pinController.clear();

      setState(() {
        _isChecking = false;
        _errorMessage = 'Incorrect PIN. Please try again.';
      });

      _pinFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isChecking = false;
        _errorMessage = 'Unable to verify PIN. Please try again.';
      });

      _pinFocusNode.requestFocus();
    }
  }

  // ============================================================
  // BIOMETRIC AUTHENTICATION
  // ============================================================

  Future<void> _authenticateBiometric() async {
    if (_isChecking || _isBiometricChecking) {
      return;
    }

    if (!_biometricEnabled || !_biometricAvailable) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
      _isBiometricChecking = true;
    });

    try {
      final authenticated = await _biometricService.authenticate();

      if (!mounted) return;

      setState(() {
        _isBiometricChecking = false;
      });

      if (authenticated) {
        // Biometric authentication succeeded.
        widget.onUnlocked();

        return;
      }

      // User cancelled or authentication failed.
      setState(() {
        _errorMessage = 'Biometric authentication was cancelled or failed.';
      });

      _pinFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isBiometricChecking = false;
        _errorMessage = 'Biometric authentication failed.';
      });

      _pinFocusNode.requestFocus();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isBusy = _isChecking || _isBiometricChecking;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // LOCK ICON
                  // ==================================================

                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock,
                        size: 52,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Text(
                    'Family Vault',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Vault Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Enter your PIN to access '
                    'your family information '
                    'and documents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 36,
                  ),

                  // ==================================================
                  // PIN
                  // ==================================================

                  TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    obscureText: _hidePin,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      hintText: 'Enter your PIN',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: isBusy
                            ? null
                            : () {
                                setState(() {
                                  _hidePin = !_hidePin;
                                });
                              },
                        icon: Icon(
                          _hidePin ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      counterText: '',
                      errorText: _errorMessage,
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // PIN UNLOCK BUTTON
                  // ==================================================

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: isBusy ? null : _verifyPin,
                      child: _isChecking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Unlock Vault',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // ==================================================
                  // BIOMETRIC BUTTON
                  // ==================================================

                  if (_biometricEnabled && _biometricAvailable) ...[
                    const SizedBox(
                      height: 16,
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    OutlinedButton.icon(
                      onPressed: isBusy ? null : _authenticateBiometric,
                      icon: _isBiometricChecking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.fingerprint,
                              size: 28,
                            ),
                      label: Text(
                        _isBiometricChecking
                            ? 'Authenticating...'
                            : 'Use Fingerprint / Face Unlock',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          52,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 28,
                  ),

                  // ==================================================
                  // SECURITY MESSAGE
                  // ==================================================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      const Text(
                        'Your vault is protected',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
