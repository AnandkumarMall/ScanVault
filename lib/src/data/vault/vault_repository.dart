import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/failure.dart';
import '../../core/json_utils.dart';
import '../../domain/models/doc_page.dart';
import '../../domain/models/document.dart';
import '../../domain/models/edit_params.dart';
import '../../domain/models/index_entry.dart';
import '../../domain/models/vault_config.dart';
import 'saf_gateway.dart';
import 'vault_layout.dart';
import 'vault_prefs.dart';

class ScannedPageData {
  const ScannedPageData({
    required this.original,
    required this.processed,
    required this.thumbnail,
    required this.edit,
  });

  final Uint8List original;
  final Uint8List processed;
  final Uint8List thumbnail;
  final EditParams edit;
}

class VaultRepository {
  VaultRepository({
    required SafGateway gateway,
    required VaultPrefs prefs,
    String appVersion = '0.1.0',
    Uuid uuid = const Uuid(),
  })  : _gateway = gateway,
        _prefs = prefs,
        _appVersion = appVersion,
        _uuid = uuid;

  final SafGateway _gateway;
  final VaultPrefs _prefs;
  final String _appVersion;
  final Uuid _uuid;

  VaultConfig? _config;
  // Resolved once per connection to avoid repeated tree walks.
  String? _rootUri;
  String? _documentsUri;

  VaultConfig? get config => _config;
  bool get isConnected => _config != null;

  // ── Connection lifecycle ─────────────────────────────────────────────────

  Future<VaultConfig?> connectViaPicker() async {
    final picked = await _gateway.pickVaultDirectory();
    if (picked == null) return null;
    final config =
        VaultConfig(treeUri: picked.uri, displayName: picked.name);
    await _bind(config);
    await _prefs.save(config);
    return config;
  }

  Future<VaultConfig?> reconnectFromPrefs() async {
    final saved = _prefs.read();
    if (saved == null) return null;
    final ok = await _gateway.hasWritePermission(saved.treeUri);
    if (!ok) {
      throw const VaultFailure(
        FailureKind.permissionLost,
        'The Vault folder permission is no longer valid. Reconnect the folder.',
      );
    }
    await _bind(saved);
    return saved;
  }

  /// Forgets the current Vault (release grant + clear prefs). Files are kept.
  Future<void> disconnect() async {
    final uri = _config?.treeUri;
    if (uri != null) await _gateway.releasePermission(uri);
    await _prefs.clear();
    _config = null;
    _rootUri = null;
    _documentsUri = null;
  }

  /// Ensures the folder skeleton + version.json exist, and caches dir URIs.
  Future<void> _bind(VaultConfig config) async {
    _config = config;
    _rootUri = config.treeUri;
    // Create top-level dirs (idempotent).
    for (final dir in VaultLayout.topLevelDirs) {
      final uri = await _gateway.ensureDir(config.treeUri, [dir]);
      if (dir == VaultLayout.documentsDir) _documentsUri = uri;
    }
    await _ensureVersionFile();
  }

  Future<void> _ensureVersionFile() async {
    final root = _requireRoot();
    final existing = await _gateway.readString(root, VaultLayout.versionFile);
    if (existing != null && tryDecodeObject(existing) != null) return;
    final payload = encodePretty({
      'schemaVersion': kVaultSchemaVersion,
      'appVersion': _appVersion,
    });
    await _gateway.writeStringAtomic(root, VaultLayout.versionFile, payload);
  }

  // ── Index (thin, rebuildable cache) ──────────────────────────────────────

  Future<List<IndexEntry>> loadIndex() async {
    final root = _requireRoot();
    final raw = await _gateway.readString(root, VaultLayout.indexFile);
    if (raw != null) {
      final parsed = tryDecodeObject(raw);
      final items = parsed?['documents'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(IndexEntry.fromJson)
            .toList();
      }
    }
    // Missing/corrupt → rebuild.
    return rebuildIndex();
  }

  Future<List<IndexEntry>> rebuildIndex() async {
    final docsUri = await _requireDocumentsUri();
    final children = await _gateway.list(docsUri);
    final entries = <IndexEntry>[];
    for (final dir in children) {
      if (!dir.isDir) continue;
      final metaRaw = await _gateway.readString(dir.uri, VaultLayout.metaFile);
      if (metaRaw == null) continue;
      final json = tryDecodeObject(metaRaw);
      if (json == null) continue;
      entries.add(IndexEntry.fromDocument(Document.fromJson(json)));
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _writeIndex(entries);
    return entries;
  }

  Future<void> _writeIndex(List<IndexEntry> entries) async {
    final root = _requireRoot();
    final payload = encodePretty({
      'schemaVersion': kIndexSchemaVersion,
      'documents': entries.map((e) => e.toJson()).toList(),
    });
    await _gateway.writeStringAtomic(root, VaultLayout.indexFile, payload);
  }

  // ── Documents ────────────────────────────────────────────────────────────

  Future<Document> createDocument(String name, {DateTime? now}) async {
    final docsUri = await _requireDocumentsUri();
    final id = _uuid.v4();
    final ts = now ?? DateTime.now();
    final doc = Document(
      id: id,
      name: name.trim().isEmpty ? 'Untitled' : name.trim(),
      createdAt: ts,
      updatedAt: ts,
      appVersion: _appVersion,
    );
    // Create the document folder + its subfolders up front.
    final docDir = await _gateway.ensureDir(docsUri, [id]);
    await _gateway.ensureDir(docDir, [VaultLayout.originalDir]);
    await _gateway.ensureDir(docDir, [VaultLayout.processedDir]);
    await _gateway.ensureDir(docDir, [VaultLayout.thumbsDir]);
    await _writeMeta(docDir, doc);
    await _upsertIndexEntry(IndexEntry.fromDocument(doc));
    return doc;
  }

  /// Reads a document's authoritative meta.json.
  Future<Document?> readDocument(String id) async {
    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.child(docsUri, [id]);
    if (docDir == null) return null;
    final raw = await _gateway.readString(docDir.uri, VaultLayout.metaFile);
    if (raw == null) return null;
    final json = tryDecodeObject(raw);
    return json == null ? null : Document.fromJson(json);
  }

  Future<Document> addPages(
    String docId,
    List<Uint8List> images, {
    DateTime? now,
  }) async {
    if (images.isEmpty) return _requireDocument(docId);
    final doc = await _requireDocument(docId);
    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.ensureDir(docsUri, [docId]);
    final originalUri =
        await _gateway.ensureDir(docDir, [VaultLayout.originalDir]);

    final newPages = <DocPage>[];
    for (final bytes in images) {
      final pageId = _uuid.v4();
      final fileName = '$pageId.jpg';
      await _gateway.writeBytes(originalUri, fileName, bytes, mime: 'image/jpeg');
      newPages.add(DocPage(
        id: pageId,
        originalPath: '${VaultLayout.originalDir}/$fileName',
      ));
    }
    return saveDocument(
      doc.copyWith(pages: [...doc.pages, ...newPages]),
      now: now,
    );
  }

  /// Appends a single captured/imported image as a new page.
  Future<Document> addPage(String docId, Uint8List image, {DateTime? now}) =>
      addPages(docId, [image], now: now);

  /// Merges multiple documents into a new single document.
  Future<Document> mergeDocuments(String newName, List<String> docIds) async {
    if (docIds.length < 2) {
      throw const VaultFailure(FailureKind.unknown, 'Need at least 2 documents to merge.');
    }

    // 1. Create a brand new document
    final newDoc = await createDocument(newName);
    final docsUri = await _requireDocumentsUri();
    final newDocDir = await _gateway.ensureDir(docsUri, [newDoc.id]);
    final originalUri = await _gateway.ensureDir(newDocDir, [VaultLayout.originalDir]);
    final processedUri = await _gateway.ensureDir(newDocDir, [VaultLayout.processedDir]);
    final thumbsUri = await _gateway.ensureDir(newDocDir, [VaultLayout.thumbsDir]);

    final newPages = <DocPage>[];

    // 2. Copy all pages from old documents to the new document
    for (final docId in docIds) {
      final oldDoc = await readDocument(docId);
      if (oldDoc == null) continue;

      for (final oldPage in oldDoc.pages) {
        final originalBytes = await readDocumentFile(docId, oldPage.originalPath);
        final processedBytes = oldPage.processedPath != null ? await readDocumentFile(docId, oldPage.processedPath!) : null;
        final thumbBytes = oldPage.thumbPath != null ? await readDocumentFile(docId, oldPage.thumbPath!) : null;

        if (originalBytes == null) continue;

        final pageId = _uuid.v4();
        final fileName = '$pageId.jpg';

        await _gateway.writeBytes(originalUri, fileName, originalBytes, mime: 'image/jpeg');
        if (processedBytes != null) {
          await _gateway.writeBytes(processedUri, fileName, processedBytes, mime: 'image/jpeg');
        }
        if (thumbBytes != null) {
          await _gateway.writeBytes(thumbsUri, fileName, thumbBytes, mime: 'image/jpeg');
        }

        newPages.add(DocPage(
          id: pageId,
          originalPath: '${VaultLayout.originalDir}/$fileName',
          processedPath: processedBytes != null ? '${VaultLayout.processedDir}/$fileName' : null,
          thumbPath: thumbBytes != null ? '${VaultLayout.thumbsDir}/$fileName' : null,
          edit: oldPage.edit,
        ));
      }
    }

    // 3. Save the new document
    final finalDoc = await saveDocument(newDoc.copyWith(pages: newPages));

    // 4. Delete the old documents
    for (final docId in docIds) {
      await deleteDocument(docId);
    }

    return finalDoc;
  }

  Future<Document> addScannedPages(
    String docId,
    List<ScannedPageData> pages, {
    DateTime? now,
  }) async {
    if (pages.isEmpty) return _requireDocument(docId);
    final doc = await _requireDocument(docId);
    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.ensureDir(docsUri, [docId]);
    final originalUri =
        await _gateway.ensureDir(docDir, [VaultLayout.originalDir]);
    final processedUri =
        await _gateway.ensureDir(docDir, [VaultLayout.processedDir]);
    final thumbsUri =
        await _gateway.ensureDir(docDir, [VaultLayout.thumbsDir]);

    final newPages = <DocPage>[];
    for (final page in pages) {
      final pageId = _uuid.v4();
      final fileName = '$pageId.jpg';
      await _gateway.writeBytes(originalUri, fileName, page.original,
          mime: 'image/jpeg');
      await _gateway.writeBytes(processedUri, fileName, page.processed,
          mime: 'image/jpeg');
      await _gateway.writeBytes(thumbsUri, fileName, page.thumbnail,
          mime: 'image/jpeg');
      newPages.add(DocPage(
        id: pageId,
        originalPath: '${VaultLayout.originalDir}/$fileName',
        processedPath: '${VaultLayout.processedDir}/$fileName',
        thumbPath: '${VaultLayout.thumbsDir}/$fileName',
        edit: page.edit,
      ));
    }
    return saveDocument(
      doc.copyWith(pages: [...doc.pages, ...newPages]),
      now: now,
    );
  }

  /// Reads the raw bytes of one of a document's files by its document-relative
  /// path (e.g. `original/<id>.jpg`). Null if the document or file is gone.
  Future<Uint8List?> readDocumentFile(String docId, String relativePath) async {
    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.child(docsUri, [docId]);
    if (docDir == null) return null;
    final segments = relativePath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final file = await _gateway.child(docDir.uri, segments);
    if (file == null) return null;
    return _gateway.readFileByUri(file.uri);
  }

  Future<Document> _requireDocument(String id) async {
    final doc = await readDocument(id);
    if (doc == null) {
      throw VaultFailure(FailureKind.unknown, 'Document not found: $id');
    }
    return doc;
  }

  /// Persists a document (atomic meta.json) and refreshes its index row.
  Future<Document> saveDocument(Document doc, {DateTime? now}) async {
    final docsUri = await _requireDocumentsUri();
    final updated = doc.copyWith(updatedAt: now ?? DateTime.now());
    final docDir = await _gateway.ensureDir(docsUri, [doc.id]);
    await _writeMeta(docDir, updated);
    await _upsertIndexEntry(IndexEntry.fromDocument(updated));
    return updated;
  }

  /// Renames a document (display name only; the folder id never changes).
  Future<Document?> renameDocument(String id, String newName) async {
    final doc = await readDocument(id);
    if (doc == null) return null;
    return saveDocument(doc.copyWith(name: newName));
  }

  /// Deletes a document folder and removes it from the index.
  Future<void> deleteDocument(String id) async {
    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.child(docsUri, [id]);
    if (docDir != null) {
      await _gateway.deleteByUri(docDir.uri, isDir: true);
    }
    final entries = await loadIndex();
    entries.removeWhere((e) => e.id == id);
    await _writeIndex(entries);
  }

  // ── Page-level mutations (Phase 5) ────────────────────────────────────────

  /// Replaces a single page (retake): writes new original/processed/thumb files,
  /// updates the DocPage in the pages list, and persists the document.
  ///
  /// If [processor] is provided, it will be used to generate the processed image
  /// and thumbnail from [newOriginal] and [newEdit]. Otherwise, the caller must
  /// provide [newProcessed] and [newThumb] directly.
  Future<Document> replacePage(
    String docId,
    int pageIndex,
    Uint8List newOriginal,
    EditParams newEdit, {
    DateTime? now,
    Uint8List? newProcessed,
    Uint8List? newThumb,
    Future<(Uint8List processed, Uint8List thumb)> Function(
          Uint8List original,
          EditParams edit,
        )? processor,
  }) async {
    final doc = await _requireDocument(docId);
    if (pageIndex < 0 || pageIndex >= doc.pages.length) {
      throw VaultFailure(FailureKind.unknown, 'Page index out of bounds: $pageIndex');
    }

    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.ensureDir(docsUri, [docId]);
    final originalUri = await _gateway.ensureDir(docDir, [VaultLayout.originalDir]);
    final processedUri = await _gateway.ensureDir(docDir, [VaultLayout.processedDir]);
    final thumbsUri = await _gateway.ensureDir(docDir, [VaultLayout.thumbsDir]);

    final oldPage = doc.pages[pageIndex];
    final pageId = _uuid.v4();
    final fileName = '$pageId.jpg';

    // Write new original
    await _gateway.writeBytes(originalUri, fileName, newOriginal, mime: 'image/jpeg');

    Uint8List processedBytes;
    Uint8List thumbBytes;

    if (processor != null) {
      final result = await processor(newOriginal, newEdit);
      processedBytes = result.$1;
      thumbBytes = result.$2;
    } else {
      if (newProcessed == null || newThumb == null) {
        throw VaultFailure(
          FailureKind.unknown,
          'Either processor or (newProcessed + newThumb) must be provided',
        );
      }
      processedBytes = newProcessed;
      thumbBytes = newThumb;
    }

    // Write new processed and thumbnail
    await _gateway.writeBytes(processedUri, fileName, processedBytes, mime: 'image/jpeg');
    await _gateway.writeBytes(thumbsUri, fileName, thumbBytes, mime: 'image/jpeg');

    // Delete old files (best-effort; ignore if missing)
    await _deletePageFiles(docDir, oldPage);

    // Create new DocPage with updated paths and edit
    final newPage = DocPage(
      id: pageId,
      originalPath: '${VaultLayout.originalDir}/$fileName',
      processedPath: '${VaultLayout.processedDir}/$fileName',
      thumbPath: '${VaultLayout.thumbsDir}/$fileName',
      edit: newEdit,
    );

    final newPages = List<DocPage>.from(doc.pages);
    newPages[pageIndex] = newPage;

    return saveDocument(doc.copyWith(pages: newPages), now: now);
  }

  /// Reorders pages within a document.
  Future<Document> reorderPages(
    String docId,
    int oldIndex,
    int newIndex, {
    DateTime? now,
  }) async {
    final doc = await _requireDocument(docId);
    if (oldIndex < 0 || oldIndex >= doc.pages.length) {
      throw VaultFailure(FailureKind.unknown, 'Old index out of bounds: $oldIndex');
    }
    if (newIndex < 0 || newIndex >= doc.pages.length) {
      throw VaultFailure(FailureKind.unknown, 'New index out of bounds: $newIndex');
    }
    if (oldIndex == newIndex) return doc;

    final newPages = List<DocPage>.from(doc.pages);
    final page = newPages.removeAt(oldIndex);
    newPages.insert(newIndex, page);

    return saveDocument(doc.copyWith(pages: newPages), now: now);
  }

  /// Deletes specific pages by index.
  ///
  /// Removes the DocPage entries and deletes associated files from SAF.
  /// Indices are evaluated against the current page list (0-based).
  /// For safe deletion of multiple pages, provide indices in descending order
  /// or the method will sort them descending internally.
  Future<Document> deletePages(
    String docId,
    List<int> pageIndices, {
    DateTime? now,
  }) async {
    final doc = await _requireDocument(docId);
    if (pageIndices.isEmpty) return doc;

    // Validate and deduplicate indices
    final uniqueIndices = pageIndices.toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // Descending for stable removal

    for (final idx in uniqueIndices) {
      if (idx < 0 || idx >= doc.pages.length) {
        throw VaultFailure(FailureKind.unknown, 'Page index out of bounds: $idx');
      }
    }

    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.child(docsUri, [docId]);
    if (docDir == null) {
      throw VaultFailure(FailureKind.unknown, 'Document folder not found: $docId');
    }

    // Delete files for each page being removed
    for (final idx in uniqueIndices) {
      await _deletePageFiles(docDir.uri, doc.pages[idx]);
    }

    // Remove pages from list
    final newPages = List<DocPage>.from(doc.pages);
    for (final idx in uniqueIndices) {
      newPages.removeAt(idx);
    }

    return saveDocument(doc.copyWith(pages: newPages), now: now);
  }

  /// Updates a page's edit params (after re-crop/enhance).
  ///
  /// Regenerates processed/thumb from the original image + new [edit],
  /// updates the DocPage, and persists the document.
  ///
  /// If [processor] is not provided, the caller must supply [newProcessed]
  /// and [newThumb] directly.
  Future<Document> updatePageEdit(
    String docId,
    int pageIndex,
    EditParams edit, {
    DateTime? now,
    Uint8List? newProcessed,
    Uint8List? newThumb,
    Future<(Uint8List processed, Uint8List thumb)> Function(
          Uint8List original,
          EditParams edit,
        )? processor,
  }) async {
    final doc = await _requireDocument(docId);
    if (pageIndex < 0 || pageIndex >= doc.pages.length) {
      throw VaultFailure(FailureKind.unknown, 'Page index out of bounds: $pageIndex');
    }

    final page = doc.pages[pageIndex];
    final originalBytes = await readDocumentFile(docId, page.originalPath);
    if (originalBytes == null) {
      throw VaultFailure(FailureKind.unknown, 'Original image not found for page ${page.id}');
    }

    final docsUri = await _requireDocumentsUri();
    final docDir = await _gateway.ensureDir(docsUri, [docId]);
    final processedUri = await _gateway.ensureDir(docDir, [VaultLayout.processedDir]);
    final thumbsUri = await _gateway.ensureDir(docDir, [VaultLayout.thumbsDir]);

    Uint8List processedBytes;
    Uint8List thumbBytes;

    if (processor != null) {
      final result = await processor(originalBytes, edit);
      processedBytes = result.$1;
      thumbBytes = result.$2;
    } else {
      if (newProcessed == null || newThumb == null) {
        throw VaultFailure(
          FailureKind.unknown,
          'Either processor or (newProcessed + newThumb) must be provided',
        );
      }
      processedBytes = newProcessed;
      thumbBytes = newThumb;
    }

    // Write new processed and thumbnail (same filename, overwrite)
    final processedSegments = page.processedPath!.split('/');
    final processedFileName = processedSegments.last;
    final thumbSegments = page.thumbPath!.split('/');
    final thumbFileName = thumbSegments.last;

    await _gateway.writeBytes(processedUri, processedFileName, processedBytes, mime: 'image/jpeg');
    await _gateway.writeBytes(thumbsUri, thumbFileName, thumbBytes, mime: 'image/jpeg');

    // Update DocPage with new edit params (paths stay the same)
    final updatedPage = page.copyWith(edit: edit);
    final newPages = List<DocPage>.from(doc.pages);
    newPages[pageIndex] = updatedPage;

    return saveDocument(doc.copyWith(pages: newPages), now: now);
  }

  /// Helper to delete a page's associated files from SAF.
  Future<void> _deletePageFiles(String docDirUri, DocPage page) async {
    // Delete original
    if (page.originalPath.isNotEmpty) {
      final segments = page.originalPath.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final file = await _gateway.child(docDirUri, segments);
        if (file != null) {
          await _gateway.deleteByUri(file.uri, isDir: false);
        }
      }
    }
    // Delete processed
    if (page.processedPath != null && page.processedPath!.isNotEmpty) {
      final segments = page.processedPath!.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final file = await _gateway.child(docDirUri, segments);
        if (file != null) {
          await _gateway.deleteByUri(file.uri, isDir: false);
        }
      }
    }
    // Delete thumbnail
    if (page.thumbPath != null && page.thumbPath!.isNotEmpty) {
      final segments = page.thumbPath!.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final file = await _gateway.child(docDirUri, segments);
        if (file != null) {
          await _gateway.deleteByUri(file.uri, isDir: false);
        }
      }
    }
  }

  Future<void> _writeMeta(String docDirUri, Document doc) async {
    await _gateway.writeStringAtomic(
      docDirUri,
      VaultLayout.metaFile,
      encodePretty(doc.toJson()),
    );
  }

  /// Inserts or replaces one index row, keeping the list sorted by recency.
  Future<void> _upsertIndexEntry(IndexEntry entry) async {
    final entries = await loadIndex();
    entries.removeWhere((e) => e.id == entry.id);
    entries.add(entry);
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _writeIndex(entries);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  String _requireRoot() {
    final root = _rootUri;
    if (root == null) {
      throw const VaultFailure(FailureKind.unknown, 'Vault is not connected.');
    }
    return root;
  }

  Future<String> _requireDocumentsUri() async {
    final cached = _documentsUri;
    if (cached != null) return cached;
    final uri = await _gateway.ensureDir(_requireRoot(), [
      VaultLayout.documentsDir,
    ]);
    _documentsUri = uri;
    return uri;
  }
}
