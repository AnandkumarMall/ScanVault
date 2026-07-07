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

/// A contour must cover at least this fraction of the (downscaled) frame to be
/// considered the document — filters out text blocks, logos and noise.
const double _kMinAreaFraction = 0.10;

/// Verbose OpenCV logging to help diagnose detection on-device (`adb logcat`
/// filtered on `ScanVault/cv`). Cheap; leave on until detection is dialed in.
const bool _kCvVerbose = true;

void _log(String message) {
  if (_kCvVerbose) {
    // ignore: avoid_print — intentional diagnostic, surfaces in logcat.
    print('ScanVault/cv: $message');
  }
}

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

/// OpenCV document pipeline (`dartcv4`). Heavy operations run in a **background
/// isolate** via [Isolate.run] so native work never blocks the UI; every `Mat`
/// is disposed inside the isolate (PLAN.md §5, §7b — leaked Mats are the #1
/// crash source).
///
/// If the isolate can't run OpenCV (e.g. native assets not resolvable in a
/// spawned isolate on some platforms) the work is retried **synchronously on the
/// main isolate** rather than silently failing — so detection still works, just
/// with a brief hitch. A total failure degrades gracefully: detection returns
/// `null` (manual crop) and processing returns the original bytes.
class CvProcessor {
  const CvProcessor();

  /// Detects the largest document-like quad in [jpeg]. Returns four normalized
  /// corners ordered TL, TR, BR, BL, or `null` if nothing convincing is found.
  Future<List<NormPoint>?> detectDocument(Uint8List jpeg) async {
    final flat = await _run('detect', () => _detectSync(jpeg));
    if (flat == null || flat.length != 8) {
      _log('detect: no quad returned');
      return null;
    }
    final corners = <NormPoint>[
      for (var i = 0; i < 8; i += 2) NormPoint(flat[i], flat[i + 1]),
    ];
    if (!isPlausibleQuad(corners)) {
      _log('detect: rejected implausible quad $corners');
      return null;
    }
    _log('detect: OK $corners');
    return corners;
  }

  /// Warps [jpeg] to a flattened rectangle using [edit]'s corners, applies the
  /// 90° rotation, and re-encodes as JPEG. Returns the original bytes unchanged
  /// if OpenCV fails, so saving always succeeds.
  Future<Uint8List> processPage(Uint8List jpeg, EditParams edit) async {
    final flat = _flattenCorners(edit.corners);
    final rotation = edit.rotationQuarters & 3;
    final out = await _run(
      'process',
      () => _processSync(jpeg, flat, rotation, kProcessedJpegQuality),
    );
    return out ?? jpeg;
  }

  /// Generates a small thumbnail (JPEG) from already-processed page bytes. Falls
  /// back to the input bytes on failure.
  Future<Uint8List> makeThumbnail(Uint8List processedJpeg) async {
    final out = await _run(
      'thumb',
      () => _thumbnailSync(
          processedJpeg, kThumbnailMaxSide, kThumbnailJpegQuality),
    );
    return out ?? processedJpeg;
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

  /// Runs [job] in a spawned isolate, retrying on the main isolate if the isolate
  /// throws (the native lib may not resolve in a fresh isolate on some setups).
  Future<T?> _run<T>(String tag, T Function() job) async {
    try {
      return await Isolate.run(job);
    } catch (e) {
      _log('$tag: isolate path failed ($e) — retrying on main isolate');
      try {
        return job();
      } catch (e2) {
        _log('$tag: main-isolate path also failed: $e2');
        return null;
      }
    }
  }

  static List<double>? _flattenCorners(List<NormPoint>? corners) {
    if (corners == null || corners.length != 4) return null;
    return [for (final c in corners) ...[c.x, c.y]];
  }
}

// ── OpenCV entry points (pure, top-level — every Mat disposed) ───────────────

/// Detects the document quad on a downscaled copy of [jpeg]: the largest
/// sufficiently-big contour, approximated to a convex quad (trying a few
/// tolerances), falling back to its min-area rotated rectangle. Returns eight
/// flattened normalized coordinates (TL,TR,BR,BL) or null.
List<double>? _detectSync(Uint8List jpeg) {
  final src = cv.imdecode(jpeg, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    _log('detect: imdecode produced an empty Mat');
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
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
  final dilated = cv.dilate(edges, kernel);

  final (contours, hierarchy) =
      cv.findContours(dilated, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);

  final imgArea = (smallW * smallH).toDouble();
  // Pick the single largest contour by area.
  var bestIdx = -1;
  var bestArea = 0.0;
  for (var i = 0; i < contours.length; i++) {
    final area = cv.contourArea(contours[i]);
    if (area > bestArea) {
      bestArea = area;
      bestIdx = i;
    }
  }
  _log('detect: ${contours.length} contours on ${smallW}x$smallH, '
      'largest=${(bestArea / imgArea).toStringAsFixed(3)} of frame');

  List<double>? result;
  if (bestIdx >= 0 && bestArea >= imgArea * _kMinAreaFraction) {
    final contour = contours[bestIdx];
    final quad = _quadFromContour(contour);
    result = [
      for (final p in quad) ...[
        (p.x / smallW).clamp(0.0, 1.0),
        (p.y / smallH).clamp(0.0, 1.0),
      ],
    ];
  }

  for (final m in [src, small, gray, blurred, edges, kernel, dilated]) {
    m.dispose();
  }
  contours.dispose();
  hierarchy.dispose();
  return result;
}

/// Approximates [contour] to an ordered convex quad. Tries progressively looser
/// polygon tolerances for a clean 4-point fit, then falls back to the contour's
/// minimum-area rotated rectangle (handles rounded corners / noisy edges).
List<Pt> _quadFromContour(cv.VecPoint contour) {
  final peri = cv.arcLength(contour, true);
  for (final k in const [0.02, 0.03, 0.05, 0.08]) {
    final approx = cv.approxPolyDP(contour, k * peri, true);
    final isQuad = approx.length == 4;
    List<Pt>? ordered;
    if (isQuad) {
      final pts = <Pt>[
        for (var j = 0; j < 4; j++)
          (x: approx[j].x.toDouble(), y: approx[j].y.toDouble()),
      ];
      final o = orderQuad(pts);
      if (isConvex(o)) ordered = o;
    }
    approx.dispose();
    if (ordered != null) {
      _log('detect: approx quad at epsilon=${k.toStringAsFixed(2)}');
      return ordered;
    }
  }
  // Fallback: minimum-area rotated rectangle around the contour.
  final rr = cv.minAreaRect(contour);
  final pts2f = rr.points;
  final pts = <Pt>[
    for (var j = 0; j < pts2f.length; j++)
      (x: pts2f[j].x.toDouble(), y: pts2f[j].y.toDouble()),
  ];
  pts2f.dispose();
  _log('detect: fell back to minAreaRect');
  return orderQuad(pts);
}

/// Full-resolution warp + rotate + JPEG encode.
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
