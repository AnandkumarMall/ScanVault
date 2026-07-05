/// Canonical folder/file names for the Vault layout (PLAN.md §3).
///
/// ```
/// /ScanVault/
///   version.json
///   index.json
///   documents/<id>/meta.json
///   documents/<id>/original/page_001.jpg
///   documents/<id>/processed/page_001.jpg
///   documents/<id>/thumbs/page_001.jpg
///   exports/
///   cache/
/// ```
abstract final class VaultLayout {
  static const String versionFile = 'version.json';
  static const String indexFile = 'index.json';

  static const String documentsDir = 'documents';
  static const String exportsDir = 'exports';
  static const String cacheDir = 'cache';

  static const String metaFile = 'meta.json';
  static const String originalDir = 'original';
  static const String processedDir = 'processed';
  static const String thumbsDir = 'thumbs';

  /// Top-level folders created on connect.
  static const List<String> topLevelDirs = [documentsDir, exportsDir, cacheDir];

  /// Suffix appended to a file while it is being written atomically.
  static const String tempSuffix = '.tmp';

  /// `page_001.jpg` style filename for a 1-based page number.
  static String pageFileName(int pageNumber) =>
      'page_${pageNumber.toString().padLeft(3, '0')}.jpg';
}

/// Current on-disk schema version written to version.json.
const int kVaultSchemaVersion = 1;
