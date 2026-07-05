import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/failure.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/connect_screen.dart';
import '../features/onboarding/reconnect_screen.dart';
import 'constants.dart';
import 'providers.dart';
import 'theme.dart';

class ScanVaultApp extends ConsumerWidget {
  const ScanVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ScanVaultTheme.light(),
      darkTheme: ScanVaultTheme.dark(),
      themeMode: ThemeMode.system,
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
      loading: () => const _Splash(),
      error: (err, _) {
        // A lost permission gets the dedicated reconnect flow; anything else is
        // shown as a recoverable error over the connect screen.
        if (err is VaultFailure && err.kind == FailureKind.permissionLost) {
          return ReconnectScreen(message: err.message);
        }
        return ReconnectScreen(message: '$err');
      },
      data: (config) =>
          config == null ? const ConnectScreen() : const HomeScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
