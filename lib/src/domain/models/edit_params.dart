import 'dart:convert';

import '../../core/json_utils.dart';

class NormPoint {
  const NormPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory NormPoint.fromJson(Map<String, dynamic> json) =>
      NormPoint(jsonDouble(json, 'x'), jsonDouble(json, 'y'));

  @override
  bool operator ==(Object other) =>
      other is NormPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

enum PageFilter { original, autoColor, grayscale, blackAndWhite }

PageFilter _filterFromName(String name) => PageFilter.values.firstWhere(
      (f) => f.name == name,
      orElse: () => PageFilter.original,
    );

class EditParams {
  const EditParams({
    this.corners,
    this.rotationQuarters = 0,
    this.filter = PageFilter.original,
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
  });

  final List<NormPoint>? corners;

  final int rotationQuarters;

  final PageFilter filter;

  final double brightness;
  final double contrast;
  final double sharpness;

  bool get isIdentity =>
      corners == null &&
      rotationQuarters == 0 &&
      filter == PageFilter.original &&
      brightness == 0 &&
      contrast == 0 &&
      sharpness == 0;

  EditParams copyWith({
    List<NormPoint>? corners,
    bool clearCorners = false,
    int? rotationQuarters,
    PageFilter? filter,
    double? brightness,
    double? contrast,
    double? sharpness,
  }) {
    return EditParams(
      corners: clearCorners ? null : (corners ?? this.corners),
      rotationQuarters: rotationQuarters ?? this.rotationQuarters,
      filter: filter ?? this.filter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      sharpness: sharpness ?? this.sharpness,
    );
  }

  Map<String, dynamic> toJson() => {
        if (corners != null)
          'corners': corners!.map((p) => p.toJson()).toList(),
        'rotationQuarters': rotationQuarters,
        'filter': filter.name,
        'brightness': brightness,
        'contrast': contrast,
        'sharpness': sharpness,
      };

  factory EditParams.fromJson(Map<String, dynamic> json) {
    final rawCorners = json['corners'];
    return EditParams(
      corners: rawCorners is List
          ? rawCorners
              .whereType<Map<String, dynamic>>()
              .map(NormPoint.fromJson)
              .toList()
          : null,
      rotationQuarters: jsonInt(json, 'rotationQuarters'),
      filter: _filterFromName(jsonString(json, 'filter', or: 'original')),
      brightness: jsonDouble(json, 'brightness'),
      contrast: jsonDouble(json, 'contrast'),
      sharpness: jsonDouble(json, 'sharpness'),
    );
  }

  String editHash() {
    final canonical = jsonEncode(toJson());
    // Cheap deterministic FNV-1a — no crypto needed, just cache invalidation.
    var hash = 0x811c9dc5;
    for (final code in canonical.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
