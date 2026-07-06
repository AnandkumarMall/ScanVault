import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Imports one or more images from the device gallery via the Android photo
/// picker (PLAN.md §2 Import from Gallery). Returns their raw bytes, or an empty
/// list if the user picked nothing.
///
/// The photo picker needs no storage permission on modern Android, so there is
/// nothing to request here.
Future<List<Uint8List>> pickImagesFromGallery() async {
  final files = await ImagePicker().pickMultiImage();
  final images = <Uint8List>[];
  for (final file in files) {
    images.add(await file.readAsBytes());
  }
  return images;
}

/// A sensible default document name derived from the capture time, e.g.
/// `Scan 2026-07-06 14.30`. Kept pure so it is unit-testable.
String defaultScanName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = now;
  return 'Scan ${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}.${two(d.minute)}';
}
