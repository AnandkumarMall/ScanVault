import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;

import '../../domain/models/edit_params.dart';
import 'quad_geometry.dart';

/// Longest side (px) the frame is downscaled to before edge detection. Detection
/// runs on this small copy for speed; the final warp uses full resolution
/// (PLAN.md §5 CvProcessor rules).
const int kDetectionMaxSide = 640;

/// Longest side (px) for cached page thumbnails.
const int kThumbnailMaxSide = 320;

/// JPEG quality for processed pages and thumbnails.
const int kProcessedJpegQuality = 90;
const int kThumbnailJpegQuality = 80;

/// The three image artifacts produced for one scanned page, ready to persist:
/// the untouched capture, the warped/enhanced result, and a small thumbnail —
/// plus the [EditParams] that regenerate the processed image (PLAN.md §3).
class ProcessedPage {
  const ProcessedPage({
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

/// OpenCV document pipeline (`dartcv4`). Every operation runs in a **background
/// isolate** via [Isolate.run] so the heavy native work never blocks the UI, and
/// every `Mat` is disposed inside the isolate (PLAN.md §5, §7b — leaked Mats are
/// the #1 crash source).
///
/// All methods are failure-tolerant: if OpenCV is unavailable or throws, detection
/// returns `null` (the user crops manually) and processing falls back to the
/// original bytes, so a scan is never lost.
class CvProcessor {
  const CvProcessor();

  /// Detects the largest document-like quad in [jpeg]. Returns four normalized
  /// corners ordered TL, TR, BR, BL, or `null` if nothing convincing is found.
  Future<List<NormPoint>?> detectDocument(Uint8List jpeg) async {
    try {
      final flat = await Isolate.run(() => _detectSync(jpeg));
      if (flat == null) return null;
      final corners = <NormPoint>[
        for (var i = 0; i < 8; i += 2) NormPoint(flat[i], flat[i + 1]),
      ];
      return isPlausibleQuad(corners) ? corners : null;
    } catch (_) {
      // Native OpenCV missing/failed → fall back to manual crop.
      return null;
    }
  }

  /// Warps [jpeg] to a flattened rectangle using [edit]'s corners, applies the
  /// 90° rotation, and re-encodes as JPEG. Returns the original bytes unchanged
  /// if OpenCV fails, so saving always succeeds.
  Future<Uint8List> processPage(Uint8List jpeg, EditParams edit) async {
    final flat = _flattenCorners(edit.corners);
    final rotation = edit.rotationQuarters & 3;
    try {
      return await Isolate.run(
        () => _processSync(jpeg, flat, rotation, kProcessedJpegQuality),
      );
    } catch (_) {
      return jpeg;
    }
  }

  /// Generates a small thumbnail (JPEG) from already-processed page bytes. Falls
  /// back to the input bytes on failure.
  Future<Uint8List> makeThumbnail(Uint8List processedJpeg) async {
    try {
      return await Isolate.run(
        () => _thumbnailSync(processedJpeg, kThumbnailMaxSide,
            kThumbnailJpegQuality),
      );
    } catch (_) {
      return processedJpeg;
    }
  }

  /// Runs the whole capture→save pipeline for one page: warp then thumbnail.
  Future<ProcessedPage> buildPage(Uint8List original, EditParams edit) async {
    final processed = await processPage(original, edit);
    final thumb = await makeThumbnail(processed);
    return ProcessedPage(
      original: original,
      processed: processed,
      thumbnail: thumb,
      edit: edit,
    );
  }

  static List<double>? _flattenCorners(List<NormPoint>? corners) {
    if (corners == null || corners.length != 4) return null;
    return [for (final c in corners) ...[c.x, c.y]];
  }
}

// ── Isolate entry points (top-level, pure — every Mat disposed) ──────────────

/// Detects the largest 4-point contour on a downscaled copy of [jpeg]. Returns
/// eight flattened normalized coordinates (TL,TR,BR,BL) or null. Runs in a
/// spawned isolate.
List<double>? _detectSync(Uint8List jpeg) {
  final src = cv.imdecode(jpeg, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    return null;
  }
  final fullW = src.width.toDouble();
  final fullH = src.height.toDouble();
  final longest = fullW > fullH ? fullW : fullH;
  final scale = longest > kDetectionMaxSide ? kDetectionMaxSide / longest : 1.0;
  final smallW = (fullW * scale).round().clamp(1, 1 << 20);
  final smallH = (fullH * scale).round().clamp(1, 1 << 20);

  final small = cv.resize(src, (smallW, smallH), interpolation: cv.INTER_AREA);
  final gray = cv.cvtColor(small, cv.COLOR_BGR2GRAY);
  final blurred = cv.gaussianBlur(gray, (5, 5), 0);
  final edges = cv.canny(blurred, 75, 200);
  final kernel =
      cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
  final dilated = cv.dilate(edges, kernel);

  final (contours, hierarchy) =
      cv.findContours(dilated, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);

  final imgArea = smallW * smallH;
  List<double>? best;
  var bestArea = 0.0;
  for (var i = 0; i < contours.length; i++) {
    final contour = contours[i];
    final area = cv.contourArea(contour);
    // Ignore specks; a document should cover a decent share of the frame.
    if (area < imgArea * 0.15 || area <= bestArea) continue;
    final peri = cv.arcLength(contour, true);
    final approx = cv.approxPolyDP(contour, 0.02 * peri, true);
    if (approx.length == 4) {
      final pts = <Pt>[
        for (var j = 0; j < 4; j++)
          (x: approx[j].x.toDouble(), y: approx[j].y.toDouble()),
      ];
      final ordered = orderQuad(pts);
      if (isConvex(ordered)) {
        bestArea = area;
        best = [
          for (final p in ordered) ...[
            (p.x / smallW).clamp(0.0, 1.0),
            (p.y / smallH).clamp(0.0, 1.0),
          ],
        ];
      }
    }
    approx.dispose();
  }

  for (final m in [src, small, gray, blurred, edges, kernel, dilated]) {
    m.dispose();
  }
  contours.dispose();
  hierarchy.dispose();
  return best;
}

/// Full-resolution warp + rotate + JPEG encode. Runs in a spawned isolate.
Uint8List _processSync(
  Uint8List jpeg,
  List<double>? flatCorners,
  int rotationQuarters,
  int quality,
) {
  final src = cv.imdecode(jpeg, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    return jpeg;
  }
  final toDispose = <cv.Mat>[src];
  cv.Mat current = src;

  if (flatCorners != null && flatCorners.length == 8) {
    final w = src.width.toDouble();
    final h = src.height.toDouble();
    final pts = <Pt>[
      for (var i = 0; i < 8; i += 2)
        (x: flatCorners[i] * w, y: flatCorners[i + 1] * h),
    ];
    final ordered = orderQuad(pts);
    final size = flattenedSize(ordered);

    final srcVec = cv.VecPoint.fromList([
      for (final p in ordered) cv.Point(p.x.round(), p.y.round()),
    ]);
    final dstVec = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(size.width - 1, 0),
      cv.Point(size.width - 1, size.height - 1),
      cv.Point(0, size.height - 1),
    ]);
    final transform = cv.getPerspectiveTransform(srcVec, dstVec);
    final warped =
        cv.warpPerspective(src, transform, (size.width, size.height));
    srcVec.dispose();
    dstVec.dispose();
    transform.dispose();
    toDispose.add(warped);
    current = warped;
  }

  final rotateCode = _rotateCodeFor(rotationQuarters);
  if (rotateCode != null) {
    final rotated = cv.rotate(current, rotateCode);
    toDispose.add(rotated);
    current = rotated;
  }

  final (ok, encoded) = cv.imencode(
    '.jpg',
    current,
    params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, quality]),
  );
  for (final m in toDispose) {
    m.dispose();
  }
  return ok ? encoded : jpeg;
}

Uint8List _thumbnailSync(Uint8List jpeg, int maxSide, int quality) {
  final src = cv.imdecode(jpeg, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    return jpeg;
  }
  final w = src.width.toDouble();
  final h = src.height.toDouble();
  final longest = w > h ? w : h;
  final scale = longest > maxSide ? maxSide / longest : 1.0;
  final tw = (w * scale).round().clamp(1, 1 << 20);
  final th = (h * scale).round().clamp(1, 1 << 20);
  final small = cv.resize(src, (tw, th), interpolation: cv.INTER_AREA);
  final (ok, encoded) = cv.imencode(
    '.jpg',
    small,
    params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, quality]),
  );
  src.dispose();
  small.dispose();
  return ok ? encoded : jpeg;
}

/// Maps 90° rotation steps (1..3) to OpenCV rotate codes; null means no rotation.
int? _rotateCodeFor(int quarters) {
  switch (quarters & 3) {
    case 1:
      return cv.ROTATE_90_CLOCKWISE;
    case 2:
      return cv.ROTATE_180;
    case 3:
      return cv.ROTATE_90_COUNTERCLOCKWISE;
    default:
      return null;
  }
}
