import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Shown when the saved Vault permission is no longer valid (uninstall, SD card
/// removed, revoked). Honest copy — reconnect the *same* folder (PLAN.md §3).
class ReconnectScreen extends ConsumerWidget {
  const ReconnectScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.link_off, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 24),
              Text(
                'Reconnect your Vault',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    'We lost access to your Vault folder. Pick the same folder '
                        'again to restore your documents.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(vaultConnectionProvider.notifier).connect(),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Reconnect folder'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.read(vaultConnectionProvider.notifier).retry(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
