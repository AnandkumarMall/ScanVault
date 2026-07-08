import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/cv/cv_processor.dart';
import '../../domain/models/edit_params.dart';

/// Shared upper bound for the sliders.
const double _kSliderMax = 100.0;

class EnhanceScreen extends StatefulWidget {
  const EnhanceScreen({
    super.key,
    required this.title,
    required this.original,
    required this.elided,
    required this.processor,
  });

  final String title;
  final Uint8List original;       // already-warped page JPEG
  final EditParams elided;         // crop/rot editparams that produced [original]
  final CvProcessor processor;

  @override
  State<EnhanceScreen> createState() => _EnhanceScreenState();
}

class _EnhanceScreenState extends State<EnhanceScreen> {
  late _PageEdit _page;

  @override
  void initState() {
    super.initState();
    _page = _PageEdit.fromParams(widget.elided);
  }

  void _onFilterTap(PageFilter filter) {
    setState(() => _page.filter = filter);
  }

  void _finish() {
    final params = EditParams(
      corners: widget.elided.corners,
      rotationQuarters: widget.elided.rotationQuarters,
      filter: _page.filter,
      brightness: _page.brightness,
      contrast: _page.contrast,
      sharpness: _page.sharpness,
    );
    Navigator.of(context).pop<List<EditParams>>([params]);
  }

  List<double> _computeColorMatrix() {
    final alpha = 1.0 + (_page.contrast / 100.0);
    final offset = _page.brightness * 1.5;

    List<double> mat;
    switch (_page.filter) {
      case PageFilter.grayscale:
      case PageFilter.blackAndWhite:
        mat = [
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      case PageFilter.autoColor:
        // Slight contrast boost to proxy CLAHE
        mat = [
          1.1, 0, 0, 0, -12,
          0, 1.1, 0, 0, -12,
          0, 0, 1.1, 0, -12,
          0, 0, 0, 1, 0,
        ];
        break;
      case PageFilter.original:
      default:
        mat = [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
    }

    for (int i = 0; i < 3; i++) {
      mat[i * 5 + 0] *= alpha;
      mat[i * 5 + 1] *= alpha;
      mat[i * 5 + 2] *= alpha;
      mat[i * 5 + 4] = mat[i * 5 + 4] * alpha + offset;
    }

    if (_page.filter == PageFilter.blackAndWhite) {
      for (int i = 0; i < 3; i++) {
        mat[i * 5 + 0] *= 10.0;
        mat[i * 5 + 1] *= 10.0;
        mat[i * 5 + 2] *= 10.0;
        mat[i * 5 + 4] = mat[i * 5 + 4] * 10.0 - (128.0 * 9.0);
      }
    }
    return mat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _finish,
            tooltip: 'Done',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                  ),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(_computeColorMatrix()),
                        child: Image.memory(widget.original, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FilterChip(
                    icon: Icons.filter_none,
                    label: 'Original',
                    filter: PageFilter.original,
                    selected: _page.filter,
                    onTap: _onFilterTap,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    icon: Icons.auto_awesome,
                    label: 'Magic',
                    filter: PageFilter.autoColor,
                    selected: _page.filter,
                    onTap: _onFilterTap,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    icon: Icons.filter_b_and_w,
                    label: 'Gray',
                    filter: PageFilter.grayscale,
                    selected: _page.filter,
                    onTap: _onFilterTap,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    icon: Icons.filter_drama,
                    label: 'B&W',
                    filter: PageFilter.blackAndWhite,
                    selected: _page.filter,
                    onTap: _onFilterTap,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SliderRow(
                  icon: Icons.brightness_6,
                  label: 'Brightness',
                  value: (_page.brightness + _kSliderMax) / (_kSliderMax * 2),
                  onChanged: (v) {
                    setState(() => _page.brightness = v * _kSliderMax * 2 - _kSliderMax);
                  },
                ),
                const SizedBox(height: 4),
                _SliderRow(
                  icon: Icons.contrast,
                  label: 'Contrast',
                  value: (_page.contrast + _kSliderMax) / (_kSliderMax * 2),
                  onChanged: (v) {
                    setState(() => _page.contrast = v * _kSliderMax * 2 - _kSliderMax);
                  },
                ),
                const SizedBox(height: 4),
                _SliderRow(
                  icon: Icons.grid_view,
                  label: 'Sharpness',
                  value: (_page.sharpness + _kSliderMax) / (_kSliderMax * 2),
                  onChanged: (v) {
                    setState(() => _page.sharpness = v * _kSliderMax * 2 - _kSliderMax);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final PageFilter filter;
  final PageFilter selected;
  final ValueChanged<PageFilter> onTap;

  @override
  Widget build(BuildContext context) {
    final color = filter == selected
        ? Colors.cyanAccent
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, color: color),
      selected: filter == selected,
      onSelected: (_) => onTap(filter),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;        // normalized 0..1
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(label),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

/// Private page state mirror used by [EnhanceScreen].
class _PageEdit {
  _PageEdit({
    this.filter = PageFilter.original,
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
  });

  PageFilter filter;
  double brightness;
  double contrast;
  double sharpness;

  factory _PageEdit.fromParams(EditParams source) => _PageEdit(
    filter: source.filter,
    brightness: source.brightness,
    contrast: source.contrast,
    sharpness: source.sharpness,
  );
}
