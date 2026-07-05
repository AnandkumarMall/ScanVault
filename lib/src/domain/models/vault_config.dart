/// The connection to the user's chosen Vault folder. Only the SAF tree URI is
/// persisted in app prefs (PLAN.md §3); everything else lives in the folder.
class VaultConfig {
  const VaultConfig({
    required this.treeUri,
    this.displayName,
  });

  /// The SAF tree URI the app holds a persisted permission for.
  final String treeUri;

  /// A friendly name for the folder, if the picker provided one.
  final String? displayName;

  Map<String, dynamic> toJson() => {
        'treeUri': treeUri,
        if (displayName != null) 'displayName': displayName,
      };

  factory VaultConfig.fromJson(Map<String, dynamic> json) => VaultConfig(
        treeUri: (json['treeUri'] as String?) ?? '',
        displayName: json['displayName'] as String?,
      );
}
