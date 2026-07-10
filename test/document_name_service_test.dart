import 'package:flutter_test/flutter_test.dart';
import 'package:scanvault/src/utils/document_name_service.dart';

void main() {
  group('DocumentNameService', () {
    test('normalize works correctly', () {
      expect(DocumentNameService.normalize('Receipt'), 'receipt');
      expect(DocumentNameService.normalize('Receipt '), 'receipt');
      expect(DocumentNameService.normalize('  Receipt  '), 'receipt');
      expect(DocumentNameService.normalize('A   B'), 'a b');
      expect(DocumentNameService.normalize('File:Name?'), 'filename');
      expect(DocumentNameService.normalize('Hello/World\\|*<>?"'), 'helloworld');
    });

    test('isValid works correctly', () {
      expect(DocumentNameService.isValid(''), false);
      expect(DocumentNameService.isValid('   '), false);
      expect(DocumentNameService.isValid('a'), true);
      final longName = 'a' * 100;
      expect(DocumentNameService.isValid(longName), true);
      expect(DocumentNameService.isValid('${longName}b'), false);
    });

    test('isDuplicate works correctly', () {
      final service = DocumentNameService(['Receipt', 'Invoice 1']);
      
      expect(service.isDuplicate('receipt'), true);
      expect(service.isDuplicate('RECEIPT'), true);
      expect(service.isDuplicate('Receipt '), true);
      expect(service.isDuplicate('invoice 1'), true);
      expect(service.isDuplicate('Unknown'), false);
    });

    test('isDuplicate excludes currentName', () {
      final service = DocumentNameService(['Receipt', 'Invoice 1'], currentName: 'Receipt');
      
      // Since 'Receipt' is its own current name, saving as 'receipt' is NOT a duplicate.
      expect(service.isDuplicate('receipt'), false);
      expect(service.isDuplicate('Receipt '), false);
      
      // Other existing names still count as duplicates
      expect(service.isDuplicate('invoice 1'), true);
    });

    test('generateUniqueName standard', () {
      final service = DocumentNameService(['Receipt', 'Receipt 1', 'Receipt 10']);
      
      expect(service.generateUniqueName('Unknown'), 'Unknown');
      expect(service.generateUniqueName('Receipt'), 'Receipt 11');
      expect(service.generateUniqueName('Receipt 1'), 'Receipt 1 1'); // 'Receipt 1' exists, base is 'Receipt 1'
    });
    
    test('generateUniqueName correctly finds max', () {
      final service = DocumentNameService(['test', 'test 2', 'test 5']);
      
      expect(service.generateUniqueName('test'), 'test 6');
    });

    test('generateUniqueName isCopy behavior', () {
      final service = DocumentNameService(['Invoice', 'Invoice copy', 'Invoice copy 2']);
      
      // Duplicating 'Invoice' gives 'Invoice copy 3' since 'Invoice copy' and 'Invoice copy 2' exist.
      // Wait! In the current implementation:
      // If we duplicate 'Invoice', cleanBase becomes 'Invoice copy'.
      // 'Invoice copy' exists, so it searches for 'Invoice copy N'. Max is 2, so it yields 'Invoice copy 3'.
      expect(service.generateUniqueName('Invoice', isCopy: true), 'Invoice copy 3');
      
      // Duplicating 'Invoice copy' strips the copy and treats base as 'Invoice', thus generating 'Invoice copy 3'.
      expect(service.generateUniqueName('Invoice copy', isCopy: true), 'Invoice copy 3');
      
      // Duplicating 'Invoice copy 2' also strips down to 'Invoice', thus 'Invoice copy 3'.
      expect(service.generateUniqueName('Invoice copy 2', isCopy: true), 'Invoice copy 3');
    });
  });
}
