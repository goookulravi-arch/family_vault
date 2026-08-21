import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/security/secure_storage_service.dart';
import 'core/storage/storage_directory_manager.dart';
import 'core/theme/app_theme.dart';

import 'features/authentication/views/pin_lock_screen.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageDirectoryManager.initialize();

  runApp(
    const ProviderScope(
      child: FamilyVaultApp(),
    ),
  );
}

class FamilyVaultApp extends StatefulWidget {
  const FamilyVaultApp({
    super.key,
  });

  @override
  State<FamilyVaultApp> createState() => _FamilyVaultAppState();
}

class _FamilyVaultAppState extends State<FamilyVaultApp> {
  final SecureStorageService _secureStorage = SecureStorageService();

  bool _isCheckingLock = true;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();

    _checkAppLock();
  }

  // ============================================================
  // INITIAL APP LOCK CHECK
  // ============================================================

  Future<void> _checkAppLock() async {
    try {
      final appLockEnabled = await _secureStorage.isAppLockEnabled();

      if (!mounted) return;

      setState(() {
        _isLocked = appLockEnabled;
        _isCheckingLock = false;
      });

      // Biometric authentication is intentionally NOT
      // started automatically.
      //
      // The user must manually press:
      // "Use Fingerprint / Face Unlock"
      //
      // on the PIN lock screen.
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLocked = false;
        _isCheckingLock = false;
      });
    }
  }

  // ============================================================
  // UNLOCK
  // ============================================================

  void _unlock() {
    if (!mounted) return;

    setState(() {
      _isLocked = false;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Family Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        // ------------------------------------------------------
        // CHECKING APP LOCK
        // ------------------------------------------------------

        if (_isCheckingLock) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ------------------------------------------------------
        // LOCK SCREEN
        // ------------------------------------------------------

        if (_isLocked) {
          return PinLockScreen(
            onUnlocked: _unlock,
          );
        }

        // ------------------------------------------------------
        // NORMAL APPLICATION
        // ------------------------------------------------------

        return child ?? const SizedBox.shrink();
      },
    );
  }
}
