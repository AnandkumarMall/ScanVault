/// Typed failures surfaced by the Vault layer so the UI can react precisely
/// (e.g. show the "reconnect your Vault" flow instead of crashing — PLAN.md §3).
enum FailureKind {
  /// The saved folder URI no longer grants permission (uninstall, SD card
  /// removed, revoked). The user must re-pick the folder.
  permissionLost,

  /// The folder is reachable but its structure/manifest is missing or invalid.
  vaultCorrupt,

  /// A read/write against the SAF tree failed unexpectedly.
  io,

  /// The user cancelled a system dialog (e.g. folder picker).
  cancelled,

  /// Anything not otherwise classified.
  unknown,
}

class VaultFailure implements Exception {
  const VaultFailure(this.kind, this.message, {this.cause});

  final FailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'VaultFailure(${kind.name}): $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
