import '../../core/json_utils.dart';
import 'document.dart';

/// Current schema version for index.json.
const int kIndexSchemaVersion = 1;

/// A thin, cached summary row for the home grid (PLAN.md §3 — index.json holds
/// ONLY `{id, name, date, pageCount, cover}`). Rebuildable from meta.json.
class IndexEntry {
  const IndexEntry({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.pageCount,
    this.coverPath,
    this.tags = const [],
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final int pageCount;
  final List<String> tags;
  final bool isDeleted;

  /// Relative path (within the document folder) of the cover thumbnail/image.
  final String? coverPath;

  factory IndexEntry.fromDocument(Document doc) => IndexEntry(
        id: doc.id,
        name: doc.name,
        updatedAt: doc.updatedAt,
        pageCount: doc.pageCount,
        coverPath: doc.coverPath,
        tags: doc.tags,
        isDeleted: doc.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': updatedAt.toUtc().toIso8601String(),
        'pageCount': pageCount,
        'tags': tags,
        'isDeleted': isDeleted,
        if (coverPath != null) 'cover': coverPath,
      };

  factory IndexEntry.fromJson(Map<String, dynamic> json) => IndexEntry(
        id: jsonString(json, 'id'),
        name: jsonString(json, 'name', or: 'Untitled'),
        updatedAt: DateTime.tryParse(jsonString(json, 'date'))?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        pageCount: jsonInt(json, 'pageCount'),
        coverPath: json['cover'] is String ? json['cover'] as String : null,
        isDeleted: json['isDeleted'] == true,
        tags: json['tags'] is List 
            ? (json['tags'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}
