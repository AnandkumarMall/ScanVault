import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/providers.dart';

/// First-run onboarding: explain the Vault and let the user pick a folder.
class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key, this.isLoading = false});

  /// True while a connect attempt is in flight (picker open / initializing).
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.folder_special_outlined,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 32),
              Text(
                'Welcome to $kAppName',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Your scans live in a folder you choose — not inside the app. '
                'They stay even if you uninstall. Reinstall and reconnect the '
                'same folder to get everything back.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: pick or create a folder like "$kSuggestedVaultFolder".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref
                        .read(vaultConnectionProvider.notifier)
                        .connect(),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: Text(isLoading ? 'Connecting…' : 'Choose Vault folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
