import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/cv/cv_processor.dart';
import '../../data/cv/quad_geometry.dart';
import '../../domain/models/edit_params.dart';
import '../crop/crop_review_screen.dart';
import '../enhance/enhance_screen.dart';

class PageReviewScreen extends StatefulWidget {
  const PageReviewScreen({
    super.key,
    required this.documentId,
    required this.pageIndex,
    required this.originalBytes,
    required this.currentEdit,
    required this.processor,
  });

  final String documentId;
  final int pageIndex;
  final Uint8List originalBytes;
  final EditParams currentEdit;
  final CvProcessor processor;

  @override
  State<PageReviewScreen> createState() => _PageReviewScreenState();
}

class _PageReviewScreenState extends State<PageReviewScreen> {
  late List<NormPoint> _corners;
  late int _rotationQuarters;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _corners = List.from(widget.currentEdit.corners ?? fullFrameCorners());
    _rotationQuarters = widget.currentEdit.rotationQuarters;
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.originalBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _onCornersChanged(List<NormPoint> corners) {
    setState(() => _corners = corners);
  }

  void _rotate() {
    setState(() {
      _rotationQuarters = (_rotationQuarters + 1) & 3;
    });
  }

  void _reset() {
    setState(() {
      _corners = fullFrameCorners();
    });
  }

  Future<void> _autoDetect() async {
    final detected = await widget.processor.detectDocument(widget.originalBytes);
    if (!mounted) return;
    setState(() {
      _corners = detected ?? fullFrameCorners();
    });
  }

  Future<void> _goToEnhance() async {
    final cropParams = EditParams(
      corners: _corners,
      rotationQuarters: _rotationQuarters,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    Uint8List warped;
    try {
      warped = await widget.processor.processPage(widget.originalBytes, cropParams);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    final prefilledEdit = cropParams.copyWith(
      filter: widget.currentEdit.filter,
      brightness: widget.currentEdit.brightness,
      contrast: widget.currentEdit.contrast,
      sharpness: widget.currentEdit.sharpness,
    );

    final filtered = await Navigator.of(context).push<List<EditParams>>(
      MaterialPageRoute(
        builder: (_) => EnhanceScreen(
          title: 'Enhance',
          original: warped,
          elided: prefilledEdit,
          processor: widget.processor,
        ),
      ),
    );

    if (filtered != null && filtered.isNotEmpty && mounted) {
      Navigator.of(context).pop<EditParams>(filtered.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust crop'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _image == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: RotatedBox(
                      quarterTurns: _rotationQuarters,
                      child: CropEditor(
                        image: _image!,
                        corners: _corners,
                        onChanged: _onCornersChanged,
                      ),
                    ),
                  ),
          ),
          _buildToolbar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            icon: Icons.document_scanner_outlined,
            label: 'Auto',
            onTap: _autoDetect,
          ),
          _ToolButton(
            icon: Icons.crop_free,
            label: 'Full page',
            onTap: _reset,
          ),
          _ToolButton(
            icon: Icons.rotate_90_degrees_cw_outlined,
            label: _rotationQuarters == 0
                ? 'Rotate'
                : '${_rotationQuarters * 90}°',
            onTap: _rotate,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: _goToEnhance,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
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
