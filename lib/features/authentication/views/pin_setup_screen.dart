import 'package:flutter/material.dart';

import '../../../core/security/secure_storage_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();

  final TextEditingController _pinController = TextEditingController();

  final TextEditingController _confirmPinController = TextEditingController();

  final FocusNode _pinFocusNode = FocusNode();

  final FocusNode _confirmPinFocusNode = FocusNode();

  bool _hidePin = true;
  bool _hideConfirmPin = true;
  bool _isSaving = false;

  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // SAVE PIN
  // ============================================================

  Future<void> _savePin() async {
    FocusScope.of(context).unfocus();

    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    // PIN must contain 4-6 digits.
    if (pin.length < 4 || pin.length > 6) {
      setState(() {
        _errorMessage = 'PIN must contain 4 to 6 digits.';
      });

      return;
    }

    // Numbers only.
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN can contain numbers only.';
      });

      return;
    }

    // Confirmation must match.
    if (pin != confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Save PIN securely.
      await _secureStorage.savePin(pin);

      // Enable app lock.
      await _secureStorage.setAppLockEnabled(
        true,
      );

      if (!mounted) return;

      // Return true to the screen that opened
      // the PIN setup screen.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to save PIN. Please try again.';
      });
    }
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
          'Set Up App Lock',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ==================================================
              // LOCK ICON
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
                    Icons.lock_outline,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'Protect Your Family Vault',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Create a PIN to protect your '
                'family information and documents.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 32),

              // ==================================================
              // PIN FIELD
              // ==================================================

              TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                obscureText: _hidePin,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 6,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  hintText: 'Enter 4 to 6 digits',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
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
                ),
                onSubmitted: (_) {
                  _confirmPinFocusNode.requestFocus();
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // CONFIRM PIN FIELD
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
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  hintText: 'Enter PIN again',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _hideConfirmPin = !_hideConfirmPin;
                      });
                    },
                    icon: Icon(
                      _hideConfirmPin ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) {
                  _savePin();
                },
              ),

              const SizedBox(height: 12),

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

              const SizedBox(height: 24),

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
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your PIN is stored using '
                        'secure device storage and '
                        'is not stored in the Family '
                        'Vault database.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ==================================================
              // ENABLE APP LOCK
              // ==================================================

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _savePin,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Enable App Lock',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Use a PIN that you can remember. '
                'You will need it whenever Family '
                'Vault is locked.',
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
