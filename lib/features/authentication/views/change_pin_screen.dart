import 'package:flutter/material.dart';

import '../../../core/security/secure_storage_service.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({
    super.key,
  });

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();

  final TextEditingController _currentPinController = TextEditingController();

  final TextEditingController _newPinController = TextEditingController();

  final TextEditingController _confirmPinController = TextEditingController();

  final FocusNode _currentPinFocusNode = FocusNode();

  final FocusNode _newPinFocusNode = FocusNode();

  final FocusNode _confirmPinFocusNode = FocusNode();

  bool _hideCurrentPin = true;
  bool _hideNewPin = true;
  bool _hideConfirmPin = true;
  bool _isChanging = false;

  String? _errorMessage;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();

    _currentPinFocusNode.dispose();
    _newPinFocusNode.dispose();
    _confirmPinFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // VALIDATE PIN
  // ============================================================

  String? _validatePin(String pin) {
    if (pin.length < 4 || pin.length > 6) {
      return 'PIN must contain 4 to 6 digits.';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return 'PIN can contain numbers only.';
    }

    return null;
  }

  // ============================================================
  // CHANGE PIN
  // ============================================================

  Future<void> _changePin() async {
    if (_isChanging) return;

    FocusScope.of(context).unfocus();

    final currentPin = _currentPinController.text.trim();

    final newPin = _newPinController.text.trim();

    final confirmPin = _confirmPinController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    // ----------------------------------------------------------
    // VALIDATE CURRENT PIN
    // ----------------------------------------------------------

    final currentError = _validatePin(currentPin);

    if (currentError != null) {
      setState(() {
        _errorMessage = 'Current PIN: $currentError';
      });

      return;
    }

    // ----------------------------------------------------------
    // VALIDATE NEW PIN
    // ----------------------------------------------------------

    final newError = _validatePin(newPin);

    if (newError != null) {
      setState(() {
        _errorMessage = 'New PIN: $newError';
      });

      return;
    }

    // ----------------------------------------------------------
    // NEW PIN MUST BE DIFFERENT
    // ----------------------------------------------------------

    if (currentPin == newPin) {
      setState(() {
        _errorMessage = 'New PIN must be different from your current PIN.';
      });

      return;
    }

    // ----------------------------------------------------------
    // CONFIRM NEW PIN
    // ----------------------------------------------------------

    if (newPin != confirmPin) {
      setState(() {
        _errorMessage = 'New PINs do not match.';
      });

      return;
    }

    setState(() {
      _isChanging = true;
    });

    try {
      // --------------------------------------------------------
      // VERIFY CURRENT PIN
      // --------------------------------------------------------

      final currentPinCorrect = await _secureStorage.verifyPin(
        currentPin,
      );

      if (!mounted) return;

      if (!currentPinCorrect) {
        _currentPinController.clear();

        setState(() {
          _isChanging = false;
          _errorMessage = 'Current PIN is incorrect.';
        });

        _currentPinFocusNode.requestFocus();

        return;
      }

      // --------------------------------------------------------
      // SAVE NEW PIN
      // --------------------------------------------------------
      //
      // IMPORTANT:
      //
      // App Lock is already enabled when this screen
      // is accessible. Therefore we ONLY replace the PIN.
      //
      // We do NOT call setAppLockEnabled(true) here.
      //
      // This prevents the old problem where the PIN was
      // successfully saved and then a later operation failed,
      // causing the UI to incorrectly report:
      //
      // "Unable to change PIN"
      //
      // --------------------------------------------------------

      await _secureStorage.savePin(newPin);

      if (!mounted) return;

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isChanging = false;
        _errorMessage = 'Unable to change PIN. Please try again.';
      });
    }
  }

  // ============================================================
  // PIN FIELD DECORATION
  // ============================================================

  InputDecoration _pinDecoration({
    required String label,
    required String hint,
    required bool hidden,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: const Icon(
        Icons.lock_outline,
      ),
      suffixIcon: IconButton(
        onPressed: _isChanging ? null : onToggle,
        icon: Icon(
          hidden ? Icons.visibility : Icons.visibility_off,
        ),
      ),
      border: const OutlineInputBorder(),
      counterText: '',
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Change PIN',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // ICON
              // ==================================================

              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.password,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'Change Your PIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Enter your current PIN, '
                'then create a new PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(
                height: 32,
              ),

              // ==================================================
              // CURRENT PIN
              // ==================================================

              TextField(
                controller: _currentPinController,
                focusNode: _currentPinFocusNode,
                obscureText: _hideCurrentPin,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 6,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _pinDecoration(
                  label: 'Current PIN',
                  hint: 'Enter current PIN',
                  hidden: _hideCurrentPin,
                  onToggle: () {
                    setState(() {
                      _hideCurrentPin = !_hideCurrentPin;
                    });
                  },
                ),
                onSubmitted: (_) {
                  _newPinFocusNode.requestFocus();
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // NEW PIN
              // ==================================================

              TextField(
                controller: _newPinController,
                focusNode: _newPinFocusNode,
                obscureText: _hideNewPin,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 6,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _pinDecoration(
                  label: 'New PIN',
                  hint: 'Enter new PIN',
                  hidden: _hideNewPin,
                  onToggle: () {
                    setState(() {
                      _hideNewPin = !_hideNewPin;
                    });
                  },
                ),
                onSubmitted: (_) {
                  _confirmPinFocusNode.requestFocus();
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // CONFIRM NEW PIN
              // ==================================================

              TextField(
                controller: _confirmPinController,
                focusNode: _confirmPinFocusNode,
                obscureText: _hideConfirmPin,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _pinDecoration(
                  label: 'Confirm New PIN',
                  hint: 'Enter new PIN again',
                  hidden: _hideConfirmPin,
                  onToggle: () {
                    setState(() {
                      _hideConfirmPin = !_hideConfirmPin;
                    });
                  },
                ),
                onSubmitted: (_) {
                  _changePin();
                },
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // ERROR MESSAGE
              // ==================================================

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(
                    top: 4,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(
                      8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // SECURITY INFORMATION
              // ==================================================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security,
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Text(
                        'Your PIN is stored using '
                        'secure device storage. '
                        'It is not stored in the '
                        'Family Vault database.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 32,
              ),

              // ==================================================
              // CHANGE PIN BUTTON
              // ==================================================

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isChanging ? null : _changePin,
                  child: _isChanging
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Change PIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              const Text(
                'Your new PIN must contain '
                '4 to 6 digits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
