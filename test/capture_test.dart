import 'package:flutter_test/flutter_test.dart';
import 'package:scanvault/src/features/capture/import_source.dart';

void main() {
  group('defaultScanName', () {
    test('formats the capture time zero-padded', () {
      final name = defaultScanName(DateTime(2026, 7, 6, 9, 5));
      expect(name, 'Scan 2026-07-06 09.05');
    });

    test('handles double-digit fields', () {
      final name = defaultScanName(DateTime(2026, 12, 25, 14, 30));
      expect(name, 'Scan 2026-12-25 14.30');
    });
  });
}
