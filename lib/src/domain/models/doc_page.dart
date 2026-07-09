import '../../core/json_utils.dart';


/// One page of a document. File paths are stored *relative to the document
/// folder* (e.g. `original/page_001.jpg`) so the whole Vault can be moved.
class DocPage {
  const DocPage({
    required this.id,
    required this.originalPath,
    this.processedPath,
    this.thumbPath,
  });

  final String id;

  /// Untouched capture — the non-destructive source (PLAN.md §3).
  final String originalPath;

  /// Cached scanned result (warp + filter applied). Null until processed.
  final String? processedPath;

  /// Small cached thumbnail, versioned by [EditParams.editHash].
  final String? thumbPath;



  /// The best path to display: processed if available, else the original.
  String get displayPath => processedPath ?? originalPath;

  DocPage copyWith({
    String? id,
    String? originalPath,
    String? processedPath,
    bool clearProcessed = false,
    String? thumbPath,
    bool clearThumb = false,
  }) {
    return DocPage(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      processedPath:
          clearProcessed ? null : (processedPath ?? this.processedPath),
      thumbPath: clearThumb ? null : (thumbPath ?? this.thumbPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalPath': originalPath,
        if (processedPath != null) 'processedPath': processedPath,
        if (thumbPath != null) 'thumbPath': thumbPath,
      };

  factory DocPage.fromJson(Map<String, dynamic> json) {
    return DocPage(
      id: jsonString(json, 'id'),
      originalPath: jsonString(json, 'originalPath'),
      processedPath: json['processedPath'] is String
          ? json['processedPath'] as String
          : null,
      thumbPath:
          json['thumbPath'] is String ? json['thumbPath'] as String : null,
    );
  }
}
