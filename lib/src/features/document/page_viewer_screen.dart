import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';

import '../../domain/models/document.dart';
import 'document_editor_screen.dart';

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
  bool _showChrome = true;

  // Removed hardcoded colors

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

  void _editCurrentPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentEditorScreen(
          document: widget.document,
          pageIndex: _currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);
    
    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Image Viewer (Base)
          GestureDetector(
            onTap: () {
              setState(() {
                _showChrome = !_showChrome;
              });
            },
            child: PageView.builder(
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
                  loading: () => Center(child: CircularProgressIndicator(color: colors.accentTeal)),
                  error: (err, _) => Center(child: Icon(Icons.error, color: ScanVaultTheme.error)),
                  data: (bytes) {
                    if (bytes == null) return Center(child: Icon(Icons.error, color: ScanVaultTheme.error));
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
          ),
          
          // 2. Fading Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showChrome ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showChrome,
                child: AppBar(
                  backgroundColor: colors.bgBase.withValues(alpha: 0.8),
                  foregroundColor: colors.textPrimary,
                  elevation: 0,
                  title: Text('Page ${_currentIndex + 1} of ${widget.document.pages.length}', style: TextStyle(color: colors.textPrimary)),
                  iconTheme: IconThemeData(color: colors.textPrimary),
                ),
              ),
            ),
          ),
          
          // 3. Fading Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showChrome ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showChrome,
                child: BottomAppBar(
                  color: colors.bgSurface.withValues(alpha: 0.8),
                  elevation: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: _editCurrentPage,
                        icon: Icon(Icons.crop, color: colors.textPrimary),
                        label: Text('Edit Page', style: TextStyle(color: colors.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
