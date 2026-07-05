import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/data/vault/vault_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the persisted Vault URI up front so the reconnect attempt can run
  // synchronously in the provider graph.
  final prefs = await VaultPrefs.load();

  runApp(
    ProviderScope(
      overrides: [vaultPrefsProvider.overrideWithValue(prefs)],
      child: const ScanVaultApp(),
    ),
  );
}
