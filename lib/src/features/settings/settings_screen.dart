import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../auth/pin_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);
    final currentTheme = ref.watch(themeModeProvider);
    final hasPin = ref.watch(vaultPrefsProvider).hasPin;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Theme Section
          Text('Appearance', style: theme.textTheme.titleMedium?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            child: Column(
              children: [
                _buildThemeTile(context, ref, 'System Default', ThemeMode.system, currentTheme, colors),
                const Divider(height: 1),
                _buildThemeTile(context, ref, 'Light Mode', ThemeMode.light, currentTheme, colors),
                const Divider(height: 1),
                _buildThemeTile(context, ref, 'Dark Mode', ThemeMode.dark, currentTheme, colors),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Security Section
          Text('Security', style: theme.textTheme.titleMedium?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            child: ListTile(
              leading: Icon(Icons.pin, color: colors.accentTeal),
              title: const Text('App PIN'),
              subtitle: Text(hasPin ? 'PIN is enabled' : 'PIN is disabled'),
              trailing: Switch(
                value: hasPin,
                activeColor: colors.accentTeal,
                onChanged: (val) async {
                  if (val) {
                    final newPin = await _promptNewPin(context);
                    if (newPin != null) {
                      await ref.read(vaultPrefsProvider).setPin(newPin);
                      // Force a rebuild by reloading or navigating
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SettingsScreen())
                      );
                    }
                  } else {
                    await ref.read(vaultPrefsProvider).removePin();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SettingsScreen())
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          Text('About', style: theme.textTheme.titleMedium?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            child: ListTile(
              leading: Icon(Icons.info_outline, color: colors.textTertiary),
              title: const Text('ScanVault Version'),
              subtitle: const Text('v0.4.0 (Offline & Encrypted)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, WidgetRef ref, String title, ThemeMode mode, ThemeMode currentMode, ScanVaultColors colors) {
    return ListTile(
      title: Text(title),
      trailing: currentMode == mode ? Icon(Icons.check, color: colors.accentTeal) : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
    );
  }

  Widget _buildCard(ScanVaultColors colors, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: colors.glassBorder, width: 1),
      ),
      child: child,
    );
  }

  Future<String?> _promptNewPin(BuildContext context) async {
    String pin = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Set new PIN'),
            content: TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              onChanged: (val) {
                setState(() => pin = val);
              },
              decoration: const InputDecoration(
                hintText: 'Enter 4-6 digit PIN',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: pin.length >= 4 ? () => Navigator.of(context).pop(pin) : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
