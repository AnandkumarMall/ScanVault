import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      docFileBytesProvider((docId: widget.document.id, path: page.originalPath, version: 0)).future,
    );
    
    if (originalBytes == null || !mounted) return;


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
