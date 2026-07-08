import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/cv/cv_processor.dart';
import '../../domain/models/document.dart';
import '../../domain/models/edit_params.dart';
import 'page_review_screen.dart';

class PageViewerScreen extends ConsumerStatefulWidget {
  const PageViewerScreen({
    super.key,
    required this.document,
    required this.initialIndex,
    required this.processor,
  });

  final Document document;
  final int initialIndex;
  final CvProcessor processor;

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

    final originalBytes = await repo.readDocumentFile(
      widget.document.id,
      page.originalPath,
    );
    
    if (originalBytes == null || !mounted) return;

    final newEdit = await Navigator.of(context).push<EditParams>(
      MaterialPageRoute(
        builder: (_) => PageReviewScreen(
          documentId: widget.document.id,
          pageIndex: _currentIndex,
          originalBytes: originalBytes,
          currentEdit: page.edit,
          processor: widget.processor,
        ),
        fullscreenDialog: true,
      ),
    );

    if (newEdit != null && mounted) {
      Navigator.of(context).pop((_currentIndex, newEdit));
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
            version: page.edit.hashCode,
          )));

          return Center(
            child: bytesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => const Icon(Icons.error, color: Colors.white),
              data: (bytes) {
                if (bytes == null) return const Icon(Icons.error, color: Colors.white);
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
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
