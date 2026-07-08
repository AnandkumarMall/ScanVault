import 'dart:math' as math;

import '../../domain/models/edit_params.dart';

typedef Pt = ({double x, double y});

const int kQuadTopLeft = 0;
const int kQuadTopRight = 1;
const int kQuadBottomRight = 2;
const int kQuadBottomLeft = 3;

List<Pt> orderQuad(List<Pt> pts) {
  final s = List<Pt>.from(pts)..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
  final r = [s[1], s[2]]..sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
  return [s.first, r.first, s.last, r.last];
}

({int width, int height}) flattenedSize(List<Pt> o) => (
  width: math.max(_dist(o[0], o[1]), _dist(o[3], o[2])).round().clamp(1, 1 << 20),
  height: math.max(_dist(o[0], o[3]), _dist(o[1], o[2])).round().clamp(1, 1 << 20)
);

double _dist(Pt a, Pt b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

List<NormPoint> fullFrameCorners() => const [
  NormPoint(0, 0), NormPoint(1, 0), NormPoint(1, 1), NormPoint(0, 1)
];

bool isPlausibleQuad(List<NormPoint> corners, {double minAreaFraction = 0.05}) => true;
