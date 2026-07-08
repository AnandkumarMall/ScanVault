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
const int kThumbnailMaxSide = 256;

/// JPEG quality for processed pages and thumbnails.
const int kProcessedJpegQuality = 75;
const int kThumbnailJpegQuality = 60;

/// A contour must cover at least this fraction of the (downscaled) frame to be
/// considered the document — filters out text blocks, logos and noise.
const double _kMinAreaFraction = 0.10;

/// Slider ranges. UI maps [-1..1] from the slider to these raw values; values of
/// 0 are no-op so we can short-circuit (avoids needless Mat copies).
const double kSliderMin = -100.0;
const double kSliderMax = 100.0;

/// Listener watermark — best-effort tonal markers. Cheap and reversible: we run
/// the same pixel transform regardless of these numbers, but they show the user
/// what each filter does.
const double _kBwAdaptiveBlock = 11;
const double _kBwAdaptiveC = 10.0;

void _log(String message) {
  if (_kCvVerbose) {
    // ignore: avoid_print — intentional diagnostic, surfaces in logcat.
    print('ScanVault/cv: $message');
  }
}

// ponytail: verbose opencv log kept on until on-device behaviour is dialed in;
// switch to false once we trust the pipeline. Cheap: a single toString.
const bool _kCvVerbose = true;

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

class CvProcessor {
  const CvProcessor();

  /// Detects the largest document-like quad in [jpeg]. Returns four normalized
  /// corners ordered TL, TR, BR, BL, or `null` if nothing convincing is found.
  Future<List<NormPoint>?> detectDocument(Uint8List jpeg) async {
    final flat = await Isolate.run(() => _detectSync(jpeg)).catchError((_) => null);
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
  /// 90° rotation, runs the chosen filter + tone sliders, and re-encodes as
  /// JPEG. Returns the original bytes unchanged if OpenCV fails, so saving
  /// always succeeds (PLAN.md §Enhance / Filters).
  Future<Uint8List> processPage(Uint8List jpeg, EditParams edit) async {
    final flat = _flattenCorners(edit.corners);
    final rotation = edit.rotationQuarters & 3;
    final out = await Isolate.run(
      () => _processSync(
        jpeg,
        flat,
        rotation,
        edit.filter,
        edit.brightness,
        edit.contrast,
        edit.sharpness,
        kProcessedJpegQuality,
      ),
    ).catchError((_) => jpeg);
    return out;
  }

  /// Applies the filter + sliders to an already-warped-rotated JPEG (used for
  /// the live preview in `EnhanceScreen`). The warp step is skipped since
  /// [jpeg] is already the cropped result.
  Future<Uint8List> previewFilters(Uint8List jpeg, EditParams edit) async {
    final out = await Isolate.run(
      () => _previewFiltersSync(
        jpeg,
        edit.filter,
        edit.brightness,
        edit.contrast,
        edit.sharpness,
        kProcessedJpegQuality,
      ),
    ).catchError((_) => jpeg);
    return out;
  }

  /// Generates a small thumbnail (JPEG) from already-processed page bytes. Falls
  /// back to the input bytes on failure.
  Future<Uint8List> makeThumbnail(Uint8List processedJpeg) async {
    final out = await Isolate.run(
      () => _thumbnailSync(processedJpeg, kThumbnailMaxSide, kThumbnailJpegQuality),
    ).catchError((_) => processedJpeg);
    return out;
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
  // Pick the single largest contour by area that isn't the entire screen edge.
  var bestIdx = -1;
  var bestArea = 0.0;
  for (var i = 0; i < contours.length; i++) {
    final area = cv.contourArea(contours[i]);
    if (area > bestArea && area < imgArea * 0.98) {
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
      ordered = o;
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

/// Full-resolution warp + rotate + filter + tone adjust + JPEG encode.
Uint8List _processSync(
  Uint8List jpeg,
  List<double>? flatCorners,
  int rotationQuarters,
  PageFilter filter,
  double brightness,
  double contrast,
  double sharpness,
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

  current = _enhance(current, filter, brightness, contrast, sharpness, toDispose);

  final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, quality]);
  final (ok, encoded) = cv.imencode(
    '.jpg',
    current,
    params: params,
  );
  params.dispose();
  for (final m in toDispose) {
    m.dispose();
  }
  return ok ? encoded : jpeg;
}

/// Decodes [jpeg] and runs filter + sliders only (no warp/rotate) — used by
/// the live preview in `EnhanceScreen` where the crop is already baked in.
Uint8List _previewFiltersSync(
  Uint8List jpeg,
  PageFilter filter,
  double brightness,
  double contrast,
  double sharpness,
  int quality,
) {
  final src = cv.imdecode(jpeg, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    return jpeg;
  }
  final toDispose = <cv.Mat>[src];
  
  cv.Mat current = src;
  final w = src.width.toDouble();
  final h = src.height.toDouble();
  final longest = w > h ? w : h;
  const int maxPreviewSide = 800;
  if (longest > maxPreviewSide) {
    final scale = maxPreviewSide / longest;
    final tw = (w * scale).round().clamp(1, 1 << 20);
    final th = (h * scale).round().clamp(1, 1 << 20);
    final small = cv.resize(src, (tw, th), interpolation: cv.INTER_AREA);
    toDispose.add(small);
    current = small;
  }

  current = _enhance(current, filter, brightness, contrast, sharpness, toDispose);
  final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, quality]);
  final (ok, encoded) = cv.imencode(
    '.jpg',
    current,
    params: params,
  );
  params.dispose();
  for (final m in toDispose) {
    m.dispose();
  }
  return ok ? encoded : jpeg;
}

/// Applies the chosen [PageFilter] then the brightness/contrast/sharpness
/// sliders to [src], as a sequential pipeline so a preset and the sliders
/// compose (e.g. autoColor + a brightness boost). New Mats are appended to
/// [toDispose]; returns the latest Mat in the chain (owned by the caller).
cv.Mat _enhance(
  cv.Mat src,
  PageFilter filter,
  double brightness,
  double contrast,
  double sharpness,
  List<cv.Mat> toDispose,
) {
  cv.Mat current = src;

  // 1) Preset: reduce to a single channel for grayscale / B&W; enhance color
  //    locally for autoColor.
  switch (filter) {
    case PageFilter.grayscale:
    case PageFilter.blackAndWhite:
      final gray = cv.cvtColor(current, cv.COLOR_BGR2GRAY);
      toDispose.add(gray);
      current = gray;
    case PageFilter.autoColor:
      current = _autoColor(current, toDispose);
    case PageFilter.original:
      break;
  }

  // 2) Tone sliders (brightness offset + contrast scale) via convertTo.
  final hasTone = brightness != 0 || contrast != 0;
  if (hasTone) {
    final alpha = 1.0 + contrast / 100.0;
    final beta = brightness * 1.5;
    final adjusted = current.convertTo(current.type, alpha: alpha, beta: beta);
    toDispose.add(adjusted);
    current = adjusted;
  }

  // 3) B&W threshold runs after tone so the user can bias the binarization.
  if (filter == PageFilter.blackAndWhite) {
    final bw = cv.adaptiveThreshold(
      current,
      255.0,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY,
      _kBwAdaptiveBlock.toInt(),
      _kBwAdaptiveC,
    );
    toDispose.add(bw);
    current = bw;
  }

  // 4) Sharpness.
  if (sharpness != 0) {
    current = _sharpen(current, sharpness, toDispose);
  }

  // 5) Re-stack single-channel results to 3 channels so the JPEG encodes as a
  //    normal grayscale image and the rest of the app treats all pages alike.
  if (current.channels == 1) {
    final bgr = cv.cvtColor(current, cv.COLOR_GRAY2BGR);
    toDispose.add(bgr);
    current = bgr;
  }

  return current;
}

/// "Magic color" — CLAHE on the L channel of LAB: local contrast stretch that
/// retains color. States are /opencv4. Owns its intermediate Mats. On entry,
/// appends its temp Mats into [toDispose] and returns the final 3-channel BGR.
/// ponytail: one fixed clip limit/tile count is used instead of a slider.
cv.Mat _autoColor(cv.Mat src, List<cv.Mat> toDispose) {
  final lab = cv.cvtColor(src, cv.COLOR_BGR2Lab);
  toDispose.add(lab);
  final channels = cv.split(lab); // VecMat of [L, a, b]
  final l = channels[0];
  final a = channels[1];
  final b = channels[2];
  // Own the Mats returned from split (VecMat is just a container; its elements
  // are allocated by split and must be disposed explicitly).
  toDispose.add(l);
  toDispose.add(a);
  toDispose.add(b);
  channels.dispose();

  final blurL = cv.gaussianBlur(l, (0, 0), 25.0);
  toDispose.add(blurL);
  final lFlat = cv.divide(l, blurL, scale: 255.0);
  toDispose.add(lFlat);

  final clahe = cv.CLAHE.create(2.0, (8, 8));
  final lEq = clahe.apply(lFlat);
  toDispose.add(lEq);
  clahe.dispose();

  // Rebuild the 3-channel LAB with the equalized L (the a and b channels are the
  // same objects we have refs to via channels[1..2]).
  final mergeVec = cv.VecMat.fromList([lEq, a, b]);
  final labEq = cv.merge(mergeVec);
  mergeVec.dispose();
  toDispose.add(labEq);
  final bgr = cv.cvtColor(labEq, cv.COLOR_Lab2BGR);
  return bgr;
}

/// Unsharp-mask sharpening/softening: subtract a blurred copy and blend back.
/// [strength] ∈ (-100..100), 0 = no-op: positive sharpens, negative softens.
/// ponytail: one fixed Gaussian (σ=3); a kernel bank would be finer-grained but
/// a single slider doesn't warrant it — bump sigma if you need stronger action.
cv.Mat _sharpen(
  cv.Mat src,
  double strength,
  List<cv.Mat> toDispose,
) {
  if (strength == 0) return src;
  final blurred = cv.gaussianBlur(src, (0, 0), 3.0);
  toDispose.add(blurred);

  if (strength > 0) {
    // Sharpen
    final amount = 0.6 * strength / 100.0;
    final mixed = cv.addWeighted(src, 1.0 + amount, blurred, -amount, 0.0);
    toDispose.add(mixed);
    return mixed;
  } else {
    // Soften
    final amount = strength.abs() / 100.0;
    final mixed = cv.addWeighted(src, 1.0 - amount, blurred, amount, 0.0);
    toDispose.add(mixed);
    return mixed;
  }
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
  final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, quality]);
  final (ok, encoded) = cv.imencode(
    '.jpg',
    small,
    params: params,
  );
  params.dispose();
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
