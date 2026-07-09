import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/vault_config.dart';

/// The ONLY thing ScanVault keeps in app-private storage: the Vault folder URI
/// (PLAN.md §3). If this is wiped, the user just reconnects the folder.
class VaultPrefs {
  VaultPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _kTreeUri = 'vault.treeUri';
  static const String _kDisplayName = 'vault.displayName';
  static const String _kPin = 'vault.pin';
  static const String _kThemeMode = 'app.themeMode';

  static Future<VaultPrefs> load() async =>
      VaultPrefs(await SharedPreferences.getInstance());

  VaultConfig? read() {
    final uri = _prefs.getString(_kTreeUri);
    if (uri == null || uri.isEmpty) return null;
    return VaultConfig(
      treeUri: uri,
      displayName: _prefs.getString(_kDisplayName),
    );
  }

  Future<void> save(VaultConfig config) async {
    await _prefs.setString(_kTreeUri, config.treeUri);
    if (config.displayName != null) {
      await _prefs.setString(_kDisplayName, config.displayName!);
    } else {
      await _prefs.remove(_kDisplayName);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_kTreeUri);
    await _prefs.remove(_kDisplayName);
  }

  Future<void> setPin(String pin) async {
    await _prefs.setString(_kPin, pin);
  }

  String? getPin() {
    return _prefs.getString(_kPin);
  }

  bool get hasPin => getPin() != null;

  Future<void> removePin() async {
    await _prefs.remove(_kPin);
  }

  ThemeMode getThemeMode() {
    final mode = _prefs.getString(_kThemeMode);
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kThemeMode, mode.name);
  }
}
