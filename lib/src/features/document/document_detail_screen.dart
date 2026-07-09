import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../domain/models/document.dart';
import '../../data/vault/vault_repository.dart';
import '../../domain/models/doc_page.dart';
import 'page_viewer_screen.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'page_viewer_screen.dart';

/// Screen for viewing and managing pages within a document.
/// Mirrors OKEN's document-detail screen: numbered pages + "add new page" tile.
class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  Document? _document;
  bool _isLoading = true;
  bool _isMultiSelect = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final repo = ref.read(vaultRepositoryProvider);
    final doc = await repo.readDocument(widget.documentId);
    if (mounted) {
      setState(() {
        _document = doc;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _selectedIndices.clear();
    _isMultiSelect = false;
    await _loadDocument();
  }

  void _toggleMultiSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isMultiSelect = false;
      } else {
        _selectedIndices.add(index);
        _isMultiSelect = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _isMultiSelect = false;
    });
  }

  Future<void> _deleteSelectedPages() async {
    if (_selectedIndices.isEmpty || _document == null) return;

    final indices = _selectedIndices.toList()..sort();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final messenger = scaffoldMessenger;

    try {
      final repo = ref.read(vaultRepositoryProvider);
      final updated = await repo.deletePages(
        widget.documentId,
        indices,
      );
      if (!mounted) return;
      setState(() {
        _document = updated;
        _selectedIndices.clear();
        _isMultiSelect = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted ${indices.length} page(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _addPage() async {
    if (_document == null) return;
    
    List<String> images = [];
    try {
      images = await CunningDocumentScanner.getPictures(isGalleryImportAllowed: true) ?? [];
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanner error: $e')));
      return;
    }
    
    if (images.isEmpty || !mounted) return;

    _showProcessing(context);
    try {
      final repo = ref.read(vaultRepositoryProvider);
      final updated = await repo.addScannedPages(widget.documentId, images);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _document = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${images.length} page(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add pages: $e')),
      );
    }
  }

  Future<void> _retakePage(int index) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retake not supported')));
  }

  Future<void> _editPage(int index) async {
    if (_document == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageViewerScreen(
          document: _document!,
          initialIndex: index,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _renameDocument() async {
    if (_document == null) return;

    final controller = TextEditingController(text: _document!.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty && mounted) {
      final repo = ref.read(vaultRepositoryProvider);
      final updated = await repo.renameDocument(widget.documentId, name.trim());
      if (updated != null && mounted) {
        setState(() => _document = updated);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_document == null || _document!.pages.isEmpty) return;
    _showProcessing(context);
    try {
      final exporter = ref.read(pdfExportServiceProvider);
      final repo = ref.read(vaultRepositoryProvider);
      
      final docToExport = _isMultiSelect && _selectedIndices.isNotEmpty
          ? _document!.copyWith(
              pages: (_selectedIndices.toList()..sort()).map((i) => _document!.pages[i]).toList(),
            )
          : _document!;

      final bytes = await exporter.exportPdf(
        document: docToExport,
        vault: repo,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await Printing.sharePdf(bytes: bytes, filename: '${_document!.name}.pdf');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  Future<void> _exportImages() async {
    if (_document == null || _document!.pages.isEmpty) return;
    _showProcessing(context);
    try {
      final repo = ref.read(vaultRepositoryProvider);
      final files = <XFile>[];
      
      final pagesToExport = _isMultiSelect && _selectedIndices.isNotEmpty
          ? (_selectedIndices.toList()..sort()).map((i) => _document!.pages[i]).toList()
          : _document!.pages;

      for (int i = 0; i < pagesToExport.length; i++) {
        final page = pagesToExport[i];
        final path = page.displayPath;
        final bytes = await repo.readDocumentFile(
          widget.documentId,
          path,
        );
        if (bytes != null) {
          files.add(XFile.fromData(
            bytes,
            name: '${_document!.name}_${i + 1}.jpg',
            mimeType: 'image/jpeg',
          ));
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      if (files.isNotEmpty) {
        await Share.shareXFiles(files, text: _document!.name);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export images: $e')),
      );
    }
  }

  void _showProcessing(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 20),
              Text('Processing…'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: Text('Document not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_document!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isMultiSelect) ...[
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _renameDocument,
            ),
            IconButton(
              tooltip: 'Select',
              icon: const Icon(Icons.checklist_outlined),
              onPressed: () => setState(() => _isMultiSelect = true),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export_pdf') {
                  _exportPdf();
                } else if (value == 'export_images') {
                  _exportImages();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'export_pdf',
                  child: Text('Export as PDF'),
                ),
                PopupMenuItem(
                  value: 'export_images',
                  child: Text('Export as Images'),
                ),
              ],
            ),
          ] else ...[
            Text('${_selectedIndices.length} selected'),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export_pdf') {
                  _exportPdf();
                } else if (value == 'export_images') {
                  _exportImages();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'export_pdf',
                  child: Text('Export as PDF'),
                ),
                PopupMenuItem(
                  value: 'export_images',
                  child: Text('Export as Images'),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outlined),
              onPressed: _selectedIndices.isEmpty ? null : _deleteSelectedPages,
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _isMultiSelect ? null : _addPage,
              icon: const Icon(Icons.add_a_photo, color: Colors.grey),
              label: const Text('Add', style: TextStyle(color: Colors.grey)),
            ),
            TextButton.icon(
              onPressed: _exportImages,
              icon: const Icon(Icons.share, color: Colors.grey),
              label: const Text('Share', style: TextStyle(color: Colors.grey)),
            ),
            TextButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.grey),
              label: const Text('Export PDF', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Future<List<Uint8List>> _pickAndRasterizePdf(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return [];

    if (!context.mounted) return [];
    _showProcessing(context);
    try {
      final pdfDoc = await PdfDocument.openFile(result.files.single.path!);
      final images = <Uint8List>[];
      for (final page in pdfDoc.pages) {
        // Render at a balanced resolution (1.5x scale) to save memory and space
        final image = await page.render(
          width: (page.width * 1.5).toInt(),
          height: (page.height * 1.5).toInt(),
        );
        if (image != null) {
          final uiImage = await image.createImage();
          final byteData = await uiImage.toByteData();
          if (byteData != null) {
            final rawBytes = byteData.buffer.asUint8List();
            // Convert RGBA to JPEG using package:image
            final imgImg = img.Image.fromBytes(
              width: uiImage.width,
              height: uiImage.height,
              bytes: rawBytes.buffer,
              numChannels: 4,
            );
            images.add(img.encodeJpg(imgImg, quality: 80));
          }
          uiImage.dispose();
        }
      }
      await pdfDoc.dispose();
      if (!context.mounted) return [];
      Navigator.of(context).pop(); // dismiss loading
      return images;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import PDF: $e')),
        );
      }
      return [];
    }
  }

  Widget _buildBody() {
    if (_document!.pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No pages yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add page" to get started.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableGridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _document!.pages.length + 1, // +1 for "Add page" tile
      itemBuilder: (context, index) {
        if (index == _document!.pages.length) {
          return _AddPageTile(
            key: ValueKey('add_page'),
            onTap: _addPage,
            isMultiSelect: _isMultiSelect,
          );
        }
        return _PageTile(
          key: ValueKey(_document!.pages[index].id),
          documentId: widget.documentId,
          page: _document!.pages[index],
          pageNumber: index + 1,
          isSelected: _selectedIndices.contains(index),
          isMultiSelect: _isMultiSelect,
          onTap: () => _isMultiSelect
              ? _toggleMultiSelect(index)
              : _editPage(index),
          onLongPress: () => _toggleMultiSelect(index),
          onRetake: () => _retakePage(index),
        );
      },
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex >= _document!.pages.length ||
            newIndex >= _document!.pages.length) {
          return; // Don't reorder the "Add page" tile
        }
        if (oldIndex < newIndex) newIndex -= 1;

        final repo = ref.read(vaultRepositoryProvider);
        try {
          final updated = await repo.reorderPages(
            widget.documentId,
            oldIndex,
            newIndex,
          );
          if (mounted) {
            setState(() => _document = updated);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to reorder: $e')),
            );
          }
        }
      },
    );
  }
}

/// Tile for a single page in the document grid.
class _PageTile extends ConsumerWidget {
  const _PageTile({
    required this.documentId,
    required this.page,
    required this.pageNumber,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
    required this.onLongPress,
    required this.onRetake,
    super.key,
  });

  final String documentId;
  final DocPage page;
  final int pageNumber;
  final bool isSelected;
  final bool isMultiSelect;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: InkWell(
            onTap: onTap,
            onLongPress: isMultiSelect ? onLongPress : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PageThumbnail(documentId: documentId, page: page),
                ),
                // Page number badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pageNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                // Selection checkbox overlay
                if (isMultiSelect)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onLongPress(),
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return theme.colorScheme.primary;
                        }
                        return theme.colorScheme.surface;
                      }),
                    ),
                  ),
                if (!isMultiSelect)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]),
                      onPressed: () => _showContextMenu(context, ref),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Retake'),
              onTap: () {
                Navigator.of(context).pop();
                onRetake();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete page?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              final repo = ref.read(vaultRepositoryProvider);
              try {
                final doc = await repo.readDocument(documentId);
                if (doc != null) {
                  final index = doc.pages.indexWhere((p) => p.id == page.id);
                  if (index >= 0) {
                    await repo.deletePages(documentId, [index]);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail for a page in the document grid.
class _PageThumbnail extends ConsumerWidget {
  const _PageThumbnail({required this.documentId, required this.page});

  final String documentId;
  final DocPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.insert_drive_file_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final path = page.thumbPath ?? page.displayPath;

    final bytesAsync = ref.watch(docFileBytesProvider((
      docId: documentId,
      path: path,
      version: 0,
    )));

    // We need the document ID for the provider key - use a custom key
    // The provider will be called with the right docId in the actual usage
    return bytesAsync.when(
      loading: () => placeholder,
      error: (_, __) => placeholder,
      data: (bytes) => bytes == null
          ? placeholder
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              cacheWidth: 300,
            ),
    );
  }
}

/// "Add page" tile shown at the end of the grid.
class _AddPageTile extends StatelessWidget {
  const _AddPageTile({
    required this.onTap,
    required this.isMultiSelect,
    super.key,
  });

  final VoidCallback onTap;
  final bool isMultiSelect;

  @override
  Widget build(BuildContext context) {
    if (isMultiSelect) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tap ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 24,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Text(
                  ' to add new pages',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
