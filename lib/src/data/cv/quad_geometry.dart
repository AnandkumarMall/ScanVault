import 'dart:math' as math;

import '../../domain/models/edit_params.dart';

/// A plain 2D point used for pure geometry math (no dart:ui / OpenCV import, so
/// this whole file is unit-testable on the host without native libraries).
typedef Pt = ({double x, double y});

/// The four corners of a document quad, always ordered **TL, TR, BR, BL**.
/// Keeping a single canonical order everywhere (detection, crop UI, warp) means
/// the perspective transform maps corners to the right destination rectangle.
const int kQuadTopLeft = 0;
const int kQuadTopRight = 1;
const int kQuadBottomRight = 2;
const int kQuadBottomLeft = 3;

/// Orders four arbitrary quad corners into `[TL, TR, BR, BL]` using the classic
/// sum/difference heuristic (robust for the convex quads a document produces):
///
/// * `x + y` is smallest at the top-left, largest at the bottom-right.
/// * `y - x` is smallest at the top-right, largest at the bottom-left.
List<Pt> orderQuad(List<Pt> pts) {
  assert(pts.length == 4, 'a quad needs exactly 4 points');
  Pt argmin(double Function(Pt) key) =>
      pts.reduce((a, b) => key(a) <= key(b) ? a : b);
  Pt argmax(double Function(Pt) key) =>
      pts.reduce((a, b) => key(a) >= key(b) ? a : b);

  final tl = argmin((p) => p.x + p.y);
  final br = argmax((p) => p.x + p.y);
  final tr = argmin((p) => p.y - p.x);
  final bl = argmax((p) => p.y - p.x);
  return [tl, tr, br, bl];
}

/// The pixel size of the flattened rectangle for an **ordered** quad, taken as
/// the max of each pair of opposite edges so no content is squashed. Points must
/// be in pixel space (aspect ratio matters), not normalized.
({int width, int height}) flattenedSize(List<Pt> ordered) {
  assert(ordered.length == 4);
  double dist(Pt a, Pt b) => math.sqrt(_sq(a.x - b.x) + _sq(a.y - b.y));
  final tl = ordered[kQuadTopLeft];
  final tr = ordered[kQuadTopRight];
  final br = ordered[kQuadBottomRight];
  final bl = ordered[kQuadBottomLeft];

  final widthTop = dist(tl, tr);
  final widthBottom = dist(bl, br);
  final heightLeft = dist(tl, bl);
  final heightRight = dist(tr, br);

  // Guard against a degenerate (collapsed) quad producing a 0-size Mat.
  final width = math.max(widthTop, widthBottom).round().clamp(1, 1 << 20);
  final height = math.max(heightLeft, heightRight).round().clamp(1, 1 << 20);
  return (width: width, height: height);
}

/// The default full-frame quad (no crop): the entire image, TL→TR→BR→BL.
List<NormPoint> fullFrameCorners() => const [
      NormPoint(0, 0),
      NormPoint(1, 0),
      NormPoint(1, 1),
      NormPoint(0, 1),
    ];

/// True when [corners] describe a usable quad: four points, non-trivial area,
/// and roughly convex. Used to reject a bad auto-detection before it reaches the
/// crop UI or the warp step.
bool isPlausibleQuad(List<NormPoint> corners, {double minAreaFraction = 0.05}) {
  if (corners.length != 4) return false;
  final pts = [for (final c in corners) (x: c.x, y: c.y)];
  final area = polygonArea(pts).abs();
  if (area < minAreaFraction) return false;
  return isConvex(pts);
}

/// Signed area (shoelace) of a polygon in normalized units. Sign encodes winding
/// order; callers that only care about size use `.abs()`.
double polygonArea(List<Pt> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum / 2;
}

/// True when the polygon is convex (all cross-products share a sign). A dropped
/// or crossed corner in a bad detection shows up as a non-convex quad.
bool isConvex(List<Pt> pts) {
  if (pts.length < 3) return false;
  var sign = 0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    final c = pts[(i + 2) % pts.length];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross != 0) {
      final s = cross > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
  }
  return true;
}

double _sq(double v) => v * v;
