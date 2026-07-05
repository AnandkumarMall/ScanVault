import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vault/saf_gateway.dart';
import '../data/vault/vault_prefs.dart';
import '../data/vault/vault_repository.dart';
import '../domain/models/index_entry.dart';
import '../domain/models/vault_config.dart';
import 'constants.dart';

/// Overridden in `main()` after [VaultPrefs.load] resolves.
final vaultPrefsProvider = Provider<VaultPrefs>(
  (ref) => throw UnimplementedError('vaultPrefsProvider must be overridden'),
);

final safGatewayProvider = Provider<SafGateway>((ref) => SafGateway());

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(
    gateway: ref.watch(safGatewayProvider),
    prefs: ref.watch(vaultPrefsProvider),
    appVersion: kAppVersion,
  ),
);

/// Drives the connect / reconnect lifecycle. The value is the connected
/// [VaultConfig], or null when no Vault is connected. An [AsyncError] carrying a
/// `VaultFailure(permissionLost)` triggers the reconnect UI (PLAN.md §3).
final vaultConnectionProvider =
    AsyncNotifierProvider<VaultConnectionController, VaultConfig?>(
  VaultConnectionController.new,
);

class VaultConnectionController extends AsyncNotifier<VaultConfig?> {
  @override
  Future<VaultConfig?> build() async {
    final repo = ref.watch(vaultRepositoryProvider);
    // Attempt silent reconnect; throws VaultFailure.permissionLost if the grant
    // is gone, which surfaces as AsyncError for the UI to handle.
    return repo.reconnectFromPrefs();
  }

  /// Opens the folder picker and connects to the chosen Vault.
  Future<void> connect() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vaultRepositoryProvider);
      return repo.connectViaPicker();
    });
  }

  /// Forgets the current Vault (files are kept on disk).
  Future<void> disconnect() async {
    final repo = ref.read(vaultRepositoryProvider);
    await repo.disconnect();
    state = const AsyncValue.data(null);
  }

  /// Re-runs [build] — used by the "Try again" button after permission loss.
  void retry() => ref.invalidateSelf();
}

/// The home-screen document index. Rebuilds automatically when the connection
/// changes.
final documentIndexProvider =
    AsyncNotifierProvider<DocumentIndexController, List<IndexEntry>>(
  DocumentIndexController.new,
);

class DocumentIndexController extends AsyncNotifier<List<IndexEntry>> {
  @override
  Future<List<IndexEntry>> build() async {
    final connection = ref.watch(vaultConnectionProvider).valueOrNull;
    if (connection == null) return const [];
    final repo = ref.watch(vaultRepositoryProvider);
    return repo.loadIndex();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Creates a document then refreshes the index. Returns the new document id.
  Future<String> createDocument(String name) async {
    final repo = ref.read(vaultRepositoryProvider);
    final doc = await repo.createDocument(name);
    ref.invalidateSelf();
    await future;
    return doc.id;
  }

  Future<void> deleteDocument(String id) async {
    final repo = ref.read(vaultRepositoryProvider);
    await repo.deleteDocument(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> renameDocument(String id, String name) async {
    final repo = ref.read(vaultRepositoryProvider);
    await repo.renameDocument(id, name);
    ref.invalidateSelf();
    await future;
  }
}
