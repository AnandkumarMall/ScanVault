import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/providers.dart';

import '../../domain/models/document.dart';

class PageViewerScreen extends ConsumerStatefulWidget {
  const PageViewerScreen({
    super.key,
    required this.document,
    required this.initialIndex,
  });

  final Document document;
  final int initialIndex;


  @override
  ConsumerState<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends ConsumerState<PageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editCurrentPage() async {
    final page = widget.document.pages[_currentIndex];
    final repo = ref.read(vaultRepositoryProvider);

    final originalBytes = await ref.read(
      docFileBytesProvider((docId: widget.document.id, path: page.displayPath, version: 0)).future,
    );
    
    if (originalBytes == null || !mounted) return;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${page.id}_edit.jpg');
    await tempFile.writeAsBytes(originalBytes);

    if (!mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: tempFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop & Rotate',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
      ],
    );

    if (croppedFile != null && mounted) {
      final croppedBytes = await croppedFile.readAsBytes();
      await repo.replacePage(widget.document.id, _currentIndex, croppedBytes);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Page updated successfully')),
      );
      
      // Trigger a rebuild by forcing the bytes provider to refresh (it's autoDispose but we can just pop and let parent rebuild or we invalidate)
      ref.invalidate(docFileBytesProvider((docId: widget.document.id, path: page.displayPath, version: 0)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Page ${_currentIndex + 1} of ${widget.document.pages.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.document.pages.length,
        itemBuilder: (context, index) {
          final page = widget.document.pages[index];
          final path = page.processedPath ?? page.originalPath;
          
          final bytesAsync = ref.watch(docFileBytesProvider((
            docId: widget.document.id,
            path: path,
            version: 0,
          )));

          return bytesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => const Center(child: Icon(Icons.error, color: Colors.white)),
            data: (bytes) {
              if (bytes == null) return const Center(child: Icon(Icons.error, color: Colors.white));
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                clipBehavior: Clip.none,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _editCurrentPage,
              icon: const Icon(Icons.crop, color: Colors.white),
              label: const Text('Edit / Crop', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
