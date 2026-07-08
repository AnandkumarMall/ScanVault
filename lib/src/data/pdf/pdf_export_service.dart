import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/document.dart';
import '../vault/vault_repository.dart';

class PdfExportService {
  const PdfExportService();

  Future<Uint8List> exportPdf({
    required Document document,
    required VaultRepository vault,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document(
      title: document.name,
      creator: 'ScanVault',
    );

    for (final page in document.pages) {
      final path = page.processedPath;
      if (path == null) continue;
      final bytes = await vault.readDocumentFile(document.id, path);
      if (bytes != null) {
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: format,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }
    }
    return pdf.save();
  }
}
