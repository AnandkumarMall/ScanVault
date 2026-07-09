import 'package:flutter_test/flutter_test.dart';
import 'package:scanvault/src/domain/models/document.dart';
import 'package:scanvault/src/domain/models/doc_page.dart';

import 'package:scanvault/src/domain/models/index_entry.dart';

void main() {
  group('Document', () {
    test('json round-trip preserves pages and cover', () {
      final doc = Document(
        id: 'abc',
        name: 'hostel 4',
        createdAt: DateTime.utc(2026, 7, 5, 10),
        updatedAt: DateTime.utc(2026, 7, 5, 11),
        appVersion: '0.1.0',
        pages: const [
          DocPage(id: 'p1', originalPath: 'original/page_001.jpg'),
          DocPage(
            id: 'p2',
            originalPath: 'original/page_002.jpg',
            processedPath: 'processed/page_002.jpg',
          ),
        ],
      );
      final restored = Document.fromJson(doc.toJson());
      expect(restored.id, 'abc');
      expect(restored.name, 'hostel 4');
      expect(restored.pageCount, 2);
      expect(restored.coverPath, 'original/page_001.jpg');
      expect(restored.pages[1].displayPath, 'processed/page_002.jpg');
    });

    test('coverPath is null with no pages', () {
      final doc = Document(
        id: 'x',
        name: 'empty',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(doc.coverPath, isNull);
    });
  });

  group('IndexEntry', () {
    test('derives from a document', () {
      final doc = Document(
        id: 'id1',
        name: 'Doc',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 2),
        pages: const [DocPage(id: 'p', originalPath: 'original/page_001.jpg')],
      );
      final entry = IndexEntry.fromDocument(doc);
      expect(entry.id, 'id1');
      expect(entry.pageCount, 1);
      expect(entry.coverPath, 'original/page_001.jpg');
      // Round-trips through JSON.
      final restored = IndexEntry.fromJson(entry.toJson());
      expect(restored.id, 'id1');
      expect(restored.pageCount, 1);
      expect(restored.coverPath, 'original/page_001.jpg');
    });
  });
}
