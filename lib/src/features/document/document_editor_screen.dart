import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image/image.dart' as img;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/document.dart';

enum FilterType { original, grayscale, bw }

class _ApplyEditsConfig {
  final Uint8List bytes;
  final int rotationQuarterTurns;
  final FilterType filter;

  _ApplyEditsConfig(this.bytes, this.rotationQuarterTurns, this.filter);
}

Future<Uint8List> _applyEditsTask(_ApplyEditsConfig config) async {
  if (config.rotationQuarterTurns == 0 && config.filter == FilterType.original) {
    return config.bytes;
  }
  
  img.Image? image = img.decodeImage(config.bytes);
  if (image == null) return config.bytes;

  if (config.rotationQuarterTurns != 0) {
    image = img.copyRotate(image, angle: (config.rotationQuarterTurns % 4) * 90);
  }

  if (config.filter == FilterType.grayscale) {
    image = img.grayscale(image);
  } else if (config.filter == FilterType.bw) {
    image = img.grayscale(image);
    image = img.adjustColor(image, contrast: 1.5, amount: 1.2);
  }

  return img.encodeJpg(image, quality: 90);
}

class DocumentEditorScreen extends ConsumerStatefulWidget {
  final Document document;
  final int pageIndex;

  const DocumentEditorScreen({
    super.key,
    required this.document,
    required this.pageIndex,
  });

  @override
  ConsumerState<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  Uint8List? _originalBytes; // The base image before current edits
  bool _isProcessing = true;
  bool _showFilters = false;

  FilterType _currentFilter = FilterType.original;
  int _rotationQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialBytes();
  }

  Future<void> _loadInitialBytes() async {
    final page = widget.document.pages[widget.pageIndex];
    final path = page.processedPath ?? page.originalPath;
    final bytes = await ref.read(docFileBytesProvider((docId: widget.document.id, path: path, version: 0)).future);
    if (mounted && bytes != null) {
      setState(() {
        _originalBytes = bytes;
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_originalBytes == null) return;
    setState(() => _isProcessing = true);
    
    Uint8List finalBytes = _originalBytes!;
    if (_rotationQuarterTurns != 0 || _currentFilter != FilterType.original) {
      finalBytes = await compute(
        _applyEditsTask, 
        _ApplyEditsConfig(_originalBytes!, _rotationQuarterTurns, _currentFilter),
      );
    }
    
    final repo = ref.read(vaultRepositoryProvider);
    await repo.replacePage(widget.document.id, widget.pageIndex, finalBytes);
    
    final page = widget.document.pages[widget.pageIndex];
    ref.invalidate(docFileBytesProvider((docId: widget.document.id, path: page.displayPath, version: 0)));
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cropImage() async {
    if (_originalBytes == null) return;
    
    // Apply current rotation/filters before cropping
    setState(() => _isProcessing = true);
    Uint8List bytesForCrop = _originalBytes!;
    if (_rotationQuarterTurns != 0 || _currentFilter != FilterType.original) {
      bytesForCrop = await compute(
        _applyEditsTask, 
        _ApplyEditsConfig(_originalBytes!, _rotationQuarterTurns, _currentFilter),
      );
    }
    
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytesForCrop);

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: tempFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Document',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: ScanVaultTheme.teal,
            dimmedLayerColor: Colors.black.withValues(alpha: 0.8),
            cropFrameColor: Colors.white,
            cropGridColor: Colors.transparent,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      final newBytes = await croppedFile.readAsBytes();
      setState(() {
        _originalBytes = newBytes;
        _rotationQuarterTurns = 0;
        _currentFilter = FilterType.original;
        _isProcessing = false;
      });
    } else if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _retakePage() async {
    List<String> images = [];
    try {
      images = await CunningDocumentScanner.getPictures(isGalleryImportAllowed: true) ?? [];
    } catch (e) {
      // Handle cancellation or error
    }
    
    if (images.isNotEmpty && mounted) {
      setState(() => _isProcessing = true);
      final newFile = File(images.first);
      final newBytes = await newFile.readAsBytes();
      setState(() {
        _originalBytes = newBytes;
        _rotationQuarterTurns = 0;
        _currentFilter = FilterType.original;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgBase,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Text('Edit Page', style: TextStyle(color: colors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _saveChanges,
            child: Text('Save', style: TextStyle(color: colors.accentTeal, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_originalBytes != null)
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: Builder(
                  builder: (context) {
                    Widget imgWidget = Image.memory(
                      _originalBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    );
                    
                    if (_currentFilter == FilterType.grayscale) {
                      imgWidget = ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                        child: imgWidget,
                      );
                    } else if (_currentFilter == FilterType.bw) {
                      imgWidget = ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          1.5, 1.5, 1.5, 0, -128,
                          1.5, 1.5, 1.5, 0, -128,
                          1.5, 1.5, 1.5, 0, -128,
                          0,   0,   0,   1, 0,
                        ]),
                        child: imgWidget,
                      );
                    }
                    
                    if (_rotationQuarterTurns != 0) {
                      imgWidget = RotatedBox(
                        quarterTurns: _rotationQuarterTurns,
                        child: imgWidget,
                      );
                    }
                    
                    return imgWidget;
                  }
                ),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: colors.accentTeal),
              ),
            ),
          
          if (_showFilters && !_isProcessing)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: Colors.black87,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FilterOption(
                      label: 'Original',
                      icon: Icons.image,
                      onTap: () => setState(() => _currentFilter = FilterType.original),
                    ),
                    _FilterOption(
                      label: 'Grayscale',
                      icon: Icons.monochrome_photos,
                      onTap: () => setState(() => _currentFilter = FilterType.grayscale),
                    ),
                    _FilterOption(
                      label: 'B&W',
                      icon: Icons.contrast,
                      onTap: () => setState(() => _currentFilter = FilterType.bw),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: colors.bgBase,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.crop, color: colors.textPrimary),
              onPressed: _isProcessing ? null : _cropImage,
              tooltip: 'Crop',
            ),
            IconButton(
              icon: Icon(Icons.filter_b_and_w, color: _showFilters ? colors.accentTeal : colors.textPrimary),
              onPressed: _isProcessing ? null : () => setState(() => _showFilters = !_showFilters),
              tooltip: 'Filters',
            ),
            IconButton(
              icon: Icon(Icons.rotate_90_degrees_ccw, color: colors.textPrimary),
              onPressed: _isProcessing ? null : () => setState(() => _rotationQuarterTurns = (_rotationQuarterTurns - 1) % 4),
              tooltip: 'Rotate',
            ),
            IconButton(
              icon: Icon(Icons.camera_alt, color: colors.textPrimary),
              onPressed: _isProcessing ? null : _retakePage,
              tooltip: 'Retake',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterOption({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
