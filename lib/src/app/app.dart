import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/failure.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/connect_screen.dart';
import '../features/onboarding/reconnect_screen.dart';
import '../features/auth/pin_screen.dart';
import 'constants.dart';
import 'providers.dart';
import 'theme.dart';
import '../features/onboarding/splash_screen.dart';

class ScanVaultApp extends ConsumerWidget {
  const ScanVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ScanVaultTheme.light(),
      darkTheme: ScanVaultTheme.dark(),
      themeMode: themeMode,
      home: const _RootGate(),
    );
  }
}

/// Routes to the right top-level screen based on the Vault connection state.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(vaultConnectionProvider);
    return connection.when(
      loading: () => const Scaffold(
        backgroundColor: ScanVaultTheme.cream,
      ), // Empty screen before animation starts
      error: (err, _) {
        if (err is VaultFailure && err.kind == FailureKind.permissionLost) {
          return ReconnectScreen(message: err.message);
        }
        return ReconnectScreen(message: '$err');
      },
      data: (config) {
        Widget nextScreen;
        if (config == null) {
          nextScreen = const ConnectScreen();
        } else {
          final prefs = ref.read(vaultPrefsProvider);
          if (prefs.hasPin) {
            nextScreen = const PinScreen();
          } else {
            nextScreen = const HomeScreen();
          }
        }
        return SplashScreen(child: nextScreen);
      },
    );
  }
}
