import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/cv/cv_processor.dart';
import '../../data/cv/quad_geometry.dart';
import '../../domain/models/edit_params.dart';

/// Post-capture crop & detect step (PLAN.md §Phase 3). Walks the user through
/// every captured/imported page, pre-filling the crop with an auto-detected
/// document quad they can override by dragging the four corner handles. Pops with
/// a `List<EditParams>` (one per input image, same order), or `null` if cancelled.
class CropReviewScreen extends StatefulWidget {
  const CropReviewScreen({
    super.key,
    required this.images,
    required this.processor,
  });

  final List<Uint8List> images;
  final CvProcessor processor;

  @override
  State<CropReviewScreen> createState() => _CropReviewScreenState();
}

class _CropReviewScreenState extends State<CropReviewScreen> {
  late final List<_PageEdit> _pages;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = [
      for (final bytes in widget.images)
        _PageEdit(bytes: bytes, corners: fullFrameCorners()),
    ];
    _prepare(0);
  }

  @override
  void dispose() {
    for (final p in _pages) {
      p.image?.dispose();
    }
    super.dispose();
  }

  /// Decodes the page image and runs auto-detection the first time a page is
  /// viewed. Detection failure silently leaves the full-frame default.
  Future<void> _prepare(int i) async {
    final page = _pages[i];
    if (page.prepared) return;
    page.prepared = true;
    page.detecting = true;
    if (mounted) setState(() {});

    page.image ??= await _decodeImage(page.bytes);
    final detected = await widget.processor.detectDocument(page.bytes);
    if (!mounted) return;
    setState(() {
      if (detected != null && !page.userEdited) page.corners = detected;
      page.detecting = false;
    });
  }

  void _onCornersChanged(List<NormPoint> corners) {
    setState(() {
      _pages[_index]
        ..corners = corners
        ..userEdited = true;
    });
  }

  void _rotate() {
    setState(() {
      final p = _pages[_index];
      p.rotationQuarters = (p.rotationQuarters + 1) & 3;
    });
  }

  void _reset() {
    setState(() {
      _pages[_index]
        ..corners = fullFrameCorners()
        ..userEdited = true;
    });
  }

  Future<void> _autoDetect() async {
    final page = _pages[_index];
    setState(() => page.detecting = true);
    final detected = await widget.processor.detectDocument(page.bytes);
    if (!mounted) return;
    setState(() {
      page.corners = detected ?? fullFrameCorners();
      page.userEdited = true;
      page.detecting = false;
    });
  }

  void _goTo(int i) {
    if (i < 0 || i >= _pages.length) return;
    setState(() => _index = i);
    _prepare(i);
  }

  void _finish() {
    final edits = [
      for (final p in _pages)
        EditParams(corners: p.corners, rotationQuarters: p.rotationQuarters),
    ];
    Navigator.of(context).pop<List<EditParams>>(edits);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_pages.length == 1
            ? 'Adjust crop'
            : 'Adjust crop  ·  ${_index + 1}/${_pages.length}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: page.image == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: CropEditor(
                            image: page.image!,
                            corners: page.corners,
                            onChanged: _onCornersChanged,
                          ),
                        ),
                      ),
                      if (page.detecting)
                        const Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(child: _DetectingChip()),
                        ),
                    ],
                  ),
          ),
          _buildToolbar(page),
          _buildBottomBar(isLast),
        ],
      ),
    );
  }

  Widget _buildToolbar(_PageEdit page) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            icon: Icons.document_scanner_outlined,
            label: 'Auto',
            onTap: page.detecting ? null : _autoDetect,
          ),
          _ToolButton(
            icon: Icons.crop_free,
            label: 'Full page',
            onTap: _reset,
          ),
          _ToolButton(
            icon: Icons.rotate_90_degrees_cw_outlined,
            label: page.rotationQuarters == 0
                ? 'Rotate'
                : '${page.rotationQuarters * 90}°',
            onTap: _rotate,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isLast) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_pages.length > 1)
              TextButton.icon(
                onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            const Spacer(),
            if (isLast)
              FilledButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              )
            else
              FilledButton.icon(
                onPressed: () => _goTo(_index + 1),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Per-page editing state held by [CropReviewScreen].
class _PageEdit {
  _PageEdit({required this.bytes, required this.corners});

  final Uint8List bytes;
  List<NormPoint> corners;
  int rotationQuarters = 0;
  ui.Image? image;
  bool prepared = false;
  bool detecting = false;

  /// True once the user has manually touched this page's crop, so a later
  /// auto-detect result won't silently overwrite their adjustment.
  bool userEdited = false;
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

class _DetectingChip extends StatelessWidget {
  const _DetectingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 8),
          Text('Detecting edges…', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Colors.white38 : Colors.white;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Interactive four-corner crop editor over a single image. The image is drawn
/// with `contain` fit; corners are stored normalized (0..1) so they are
/// independent of the display size. Dragging shows a magnifier loupe so the user
/// can place a corner precisely (PLAN.md §Detect & Crop — manual crop w/ loupe).
class CropEditor extends StatefulWidget {
  const CropEditor({
    super.key,
    required this.image,
    required this.corners,
    required this.onChanged,
  });

  final ui.Image image;
  final List<NormPoint> corners;
  final ValueChanged<List<NormPoint>> onChanged;

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  static const double _hitRadius = 32;
  int? _activeCorner;
  Offset? _touch; // local position of the active drag, for the magnifier.

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = _containRect(box, widget.image.width / widget.image.height);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onStart(d.localPosition, rect),
          onPanUpdate: (d) => _onUpdate(d.localPosition, rect),
          onPanEnd: (_) => _onEnd(),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CropPainter(
                    image: widget.image,
                    corners: widget.corners,
                    imageRect: rect,
                    activeCorner: _activeCorner,
                  ),
                ),
              ),
              if (_activeCorner != null && _touch != null)
                _buildMagnifier(rect),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMagnifier(Rect rect) {
    final touch = _touch!;
    // Park the loupe above the finger, flipping below near the top edge.
    final above = touch.dy > 140;
    final pos = Offset(touch.dx - 60, above ? touch.dy - 150 : touch.dy + 40);
    return Positioned(
      left: pos.dx.clamp(0.0, rect.right - 120),
      top: pos.dy,
      child: IgnorePointer(
        child: RawMagnifier(
          size: const Size(120, 120),
          magnificationScale: 2.0,
          focalPointOffset: Offset(
            touch.dx - (pos.dx + 60),
            touch.dy - (pos.dy + 60),
          ),
          decoration: const MagnifierDecoration(
            shape: CircleBorder(
              side: BorderSide(color: Colors.white70, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  void _onStart(Offset local, Rect rect) {
    var nearest = -1;
    var best = _hitRadius;
    for (var i = 0; i < widget.corners.length; i++) {
      final p = _toLocal(widget.corners[i], rect);
      final d = (p - local).distance;
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    if (nearest >= 0) {
      setState(() {
        _activeCorner = nearest;
        _touch = local;
      });
    }
  }

  void _onUpdate(Offset local, Rect rect) {
    final i = _activeCorner;
    if (i == null) return;
    final norm = _toNorm(local, rect);
    final updated = [...widget.corners];
    updated[i] = norm;
    setState(() => _touch = local);
    widget.onChanged(updated);
  }

  void _onEnd() {
    setState(() {
      _activeCorner = null;
      _touch = null;
    });
  }

  Offset _toLocal(NormPoint n, Rect rect) =>
      Offset(rect.left + n.x * rect.width, rect.top + n.y * rect.height);

  NormPoint _toNorm(Offset local, Rect rect) {
    final nx = ((local.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final ny = ((local.dy - rect.top) / rect.height).clamp(0.0, 1.0);
    return NormPoint(nx, ny);
  }

  /// The `contain`-fit rectangle for an image of [aspect] inside [box].
  Rect _containRect(Size box, double aspect) {
    var w = box.width;
    var h = w / aspect;
    if (h > box.height) {
      h = box.height;
      w = h * aspect;
    }
    final left = (box.width - w) / 2;
    final top = (box.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.corners,
    required this.imageRect,
    required this.activeCorner,
  });

  final ui.Image image;
  final List<NormPoint> corners;
  final Rect imageRect;
  final int? activeCorner;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. The image, contained.
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint(),
    );

    final pts = [
      for (final c in corners)
        Offset(
          imageRect.left + c.x * imageRect.width,
          imageRect.top + c.y * imageRect.height,
        ),
    ];

    // 2. Dim everything outside the quad.
    final quad = Path()..addPolygon(pts, true);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(imageRect),
      quad,
    );
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.5));

    // 3. Quad edges.
    canvas.drawPath(
      quad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4CD964),
    );

    // 4. Corner handles.
    for (var i = 0; i < pts.length; i++) {
      final active = i == activeCorner;
      canvas.drawCircle(
        pts[i],
        active ? 12 : 9,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        pts[i],
        active ? 12 : 9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2E7D32),
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.corners != corners ||
      old.imageRect != imageRect ||
      old.activeCorner != activeCorner ||
      old.image != image;
}
