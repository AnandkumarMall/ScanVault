import '../../core/json_utils.dart';
import 'doc_page.dart';

/// Current on-disk schema version for a document's meta.json. Bump when the
/// shape changes so migrations can key off it (PLAN.md §3 version.json).
const int kDocumentSchemaVersion = 1;

/// The authoritative per-document record, persisted as `documents/<id>/meta.json`.
/// `index.json` is only a cache derived from these (PLAN.md §3).
class Document {
  const Document({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.pages = const [],
    this.schemaVersion = kDocumentSchemaVersion,
    this.appVersion = '',
  });

  /// UUID (no timestamp-collision risk — PLAN.md §3).
  final String id;

  /// Human display name ("hostel 4"); not used for the folder name.
  final String name;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DocPage> pages;
  final int schemaVersion;
  final String appVersion;

  int get pageCount => pages.length;

  /// Relative path of the cover image (first page's display path), or null when
  /// the document has no pages yet.
  String? get coverPath => pages.isEmpty ? null : pages.first.displayPath;

  Document copyWith({
    String? name,
    DateTime? updatedAt,
    List<DocPage>? pages,
    String? appVersion,
  }) {
    return Document(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
      schemaVersion: schemaVersion,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory Document.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'];
    return Document(
      id: jsonString(json, 'id'),
      name: jsonString(json, 'name', or: 'Untitled'),
      createdAt: _parseDate(jsonString(json, 'createdAt')),
      updatedAt: _parseDate(jsonString(json, 'updatedAt')),
      schemaVersion: jsonInt(json, 'schemaVersion', or: kDocumentSchemaVersion),
      appVersion: jsonString(json, 'appVersion'),
      pages: rawPages is List
          ? rawPages
              .whereType<Map<String, dynamic>>()
              .map(DocPage.fromJson)
              .toList()
          : const [],
    );
  }

  static DateTime _parseDate(String raw) =>
      DateTime.tryParse(raw)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
