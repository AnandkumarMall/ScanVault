import 'package:flutter_test/flutter_test.dart';
import 'package:scanvault/src/data/cv/quad_geometry.dart';
import 'package:scanvault/src/domain/models/edit_params.dart';

void main() {
  group('orderQuad', () {
    test('orders shuffled corners into TL, TR, BR, BL', () {
      // A rectangle given in scrambled order.
      final shuffled = <Pt>[
        (x: 10, y: 100), // BL
        (x: 100, y: 10), // TR
        (x: 10, y: 10), // TL
        (x: 100, y: 100), // BR
      ];
      final ordered = orderQuad(shuffled);
      expect(ordered[kQuadTopLeft], (x: 10.0, y: 10.0));
      expect(ordered[kQuadTopRight], (x: 100.0, y: 10.0));
      expect(ordered[kQuadBottomRight], (x: 100.0, y: 100.0));
      expect(ordered[kQuadBottomLeft], (x: 10.0, y: 100.0));
    });

    test('handles a mild perspective (trapezoid)', () {
      final quad = <Pt>[
        (x: 30, y: 210), // BL
        (x: 220, y: 205), // BR
        (x: 55, y: 20), // TL
        (x: 190, y: 25), // TR
      ];
      final ordered = orderQuad(quad);
      expect(ordered[kQuadTopLeft], (x: 55.0, y: 20.0));
      expect(ordered[kQuadTopRight], (x: 190.0, y: 25.0));
      expect(ordered[kQuadBottomRight], (x: 220.0, y: 205.0));
      expect(ordered[kQuadBottomLeft], (x: 30.0, y: 210.0));
    });
  });

  group('flattenedSize', () {
    test('takes the larger of each opposite edge pair', () {
      final ordered = <Pt>[
        (x: 0, y: 0),
        (x: 200, y: 0),
        (x: 180, y: 300), // bottom edge slightly shorter
        (x: 0, y: 300),
      ];
      final size = flattenedSize(ordered);
      expect(size.width, 200); // max(top=200, bottom=180)
      // Left edge is 300; the slanted right edge is ~300.7 → 301 after rounding.
      expect(size.height, 301);
    });

    test('never returns a zero dimension for a collapsed quad', () {
      final degenerate = <Pt>[
        (x: 5, y: 5),
        (x: 5, y: 5),
        (x: 5, y: 5),
        (x: 5, y: 5),
      ];
      final size = flattenedSize(degenerate);
      expect(size.width, greaterThanOrEqualTo(1));
      expect(size.height, greaterThanOrEqualTo(1));
    });
  });

  group('fullFrameCorners', () {
    test('spans the whole normalized frame in TL,TR,BR,BL order', () {
      final c = fullFrameCorners();
      expect(c, const [
        NormPoint(0, 0),
        NormPoint(1, 0),
        NormPoint(1, 1),
        NormPoint(0, 1),
      ]);
    });
  });

  group('isPlausibleQuad', () {
    test('accepts a large convex quad', () {
      expect(isPlausibleQuad(fullFrameCorners()), isTrue);
    });

    test('rejects a tiny quad below the area floor', () {
      final tiny = const [
        NormPoint(0.10, 0.10),
        NormPoint(0.12, 0.10),
        NormPoint(0.12, 0.12),
        NormPoint(0.10, 0.12),
      ];
      expect(isPlausibleQuad(tiny), isFalse);
    });

    test('rejects a self-crossing (non-convex) quad', () {
      // A "bowtie": TL and TR swapped so edges cross.
      final crossed = const [
        NormPoint(0.0, 0.0),
        NormPoint(1.0, 1.0),
        NormPoint(1.0, 0.0),
        NormPoint(0.0, 1.0),
      ];
      expect(isPlausibleQuad(crossed), isFalse);
    });
  });

  group('polygonArea', () {
    test('computes a unit square area of 1', () {
      final square = <Pt>[
        (x: 0, y: 0),
        (x: 1, y: 0),
        (x: 1, y: 1),
        (x: 0, y: 1),
      ];
      expect(polygonArea(square).abs(), closeTo(1.0, 1e-9));
    });
  });
}
