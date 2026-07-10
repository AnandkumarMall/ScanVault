class DocumentNameService {
  final Set<String> _normalizedExistingNames;
  final String? _currentName;

  DocumentNameService(Iterable<String> existingNames, {String? currentName})
      : _normalizedExistingNames = existingNames.map(normalize).toSet(),
        _currentName = currentName != null ? normalize(currentName) : null;

  /// Trims, collapses whitespace, removes forbidden chars, and lowercases
  static String normalize(String name) {
    // Remove invalid filename chars: < > : " / \ | ? *
    String s = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    // Trim and lowercase
    return s.trim().toLowerCase();
  }

  /// Validates length and emptiness
  static bool isValid(String name) {
    final s = name.trim();
    return s.isNotEmpty && s.length <= 100;
  }

  bool isDuplicate(String name) {
    final normalized = normalize(name);
    // If it's the exact same document renaming to its current name, it's not a duplicate
    if (_currentName != null && normalized == _currentName) return false;
    return _normalizedExistingNames.contains(normalized);
  }

  /// Generate a unique name by appending a number
  String generateUniqueName(String baseName, {bool isCopy = false}) {
    String cleanBase = baseName.trim();
    
    // Strip trailing ' copy' or ' copy N' if this is a duplication action
    if (isCopy) {
      final copyMatch = RegExp(r'^(.*?)(\s+copy(?:\s+\d+)?)$', caseSensitive: false).firstMatch(cleanBase);
      if (copyMatch != null) {
        cleanBase = copyMatch.group(1)!;
      }
      cleanBase = '$cleanBase copy';
    }

    final normalizedBase = normalize(cleanBase);

    // If the base name itself is completely unique, return it immediately
    if (!_normalizedExistingNames.contains(normalizedBase)) {
      return cleanBase;
    }

    // Find the highest suffix for this base name
    int maxSuffix = 0;
    
    // Create a pattern to match "$normalizedBase $number"
    final escapedBase = RegExp.escape(normalizedBase);
    final pattern = RegExp('^$escapedBase\\s+(\\d+)\$');

    for (final name in _normalizedExistingNames) {
      final match = pattern.firstMatch(name);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final number = int.tryParse(numStr);
          if (number != null && number > maxSuffix) {
            maxSuffix = number;
          }
        }
      } else if (name == normalizedBase) {
        // We know the base name exists without a number, 
        // so maxSuffix is at least 0 (if no higher numbers exist, we start at 1).
        if (maxSuffix < 0) maxSuffix = 0;
      }
    }

    return '$cleanBase ${maxSuffix + 1}';
  }
}
