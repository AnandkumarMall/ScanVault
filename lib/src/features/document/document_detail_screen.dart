import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/document.dart';
import '../../domain/models/doc_page.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import 'page_viewer_screen.dart';
import '../../utils/document_name_service.dart';
import '../../widgets/name_prompt_dialog.dart';

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
      
      if (updated.pages.isEmpty) {
        await repo.deleteDocument(widget.documentId);
        ref.read(documentIndexProvider.notifier).refresh();
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Document deleted (no pages left)')),
        );
        return;
      }

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
      images = await CunningDocumentScanner.getPictures() ?? [];
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
    if (mounted) await _loadDocument();
  }

  Future<void> _renameDocument() async {
    if (_document == null) return;

    final existingDocs = ref.read(documentIndexProvider).valueOrNull ?? [];
    final existingNames = existingDocs.map((e) => e.name);
    final service = DocumentNameService(existingNames, currentName: _document!.name);

    final name = await showDialog<String>(
      context: context,
      builder: (_) => NamePromptDialog(
        title: 'Rename document',
        initialName: _document!.name,
        nameService: service,
      ),
    );

    if (name != null && name.trim().isNotEmpty && mounted) {
      final repo = ref.read(vaultRepositoryProvider);
      try {
        final updated = await repo.renameDocument(widget.documentId, name.trim());
        if (updated != null && mounted) {
          setState(() => _document = updated);
          ref.read(documentIndexProvider.notifier).refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
        }
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
                child: CircularProgressIndicator(strokeWidth: 3, color: ScanVaultTheme.teal),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.bgBase,
        body: Center(child: CircularProgressIndicator(color: colors.accentTeal)),
      );
    }

    if (_document == null) {
      return Scaffold(
        backgroundColor: colors.bgBase,
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: Text('Document not found')),
      );
    }

    return Scaffold(
      backgroundColor: colors.bgBase,
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
              icon: Icon(Icons.more_vert, color: colors.textPrimary),
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
            Center(child: Text('${_selectedIndices.length} selected', style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colors.textPrimary),
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
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outlined, color: ScanVaultTheme.error),
              onPressed: _selectedIndices.isEmpty ? null : _deleteSelectedPages,
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: colors.bgSurface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _isMultiSelect ? null : _addPage,
              icon: Icon(Icons.add_a_photo, color: _isMultiSelect ? colors.textTertiary : colors.accentTeal),
              label: Text('Add', style: TextStyle(color: _isMultiSelect ? colors.textTertiary : colors.accentTeal)),
            ),
            TextButton.icon(
              onPressed: _exportImages,
              icon: Icon(Icons.share, color: colors.textPrimary),
              label: Text('Share', style: TextStyle(color: colors.textPrimary)),
            ),
            TextButton.icon(
              onPressed: _exportPdf,
              icon: Icon(Icons.picture_as_pdf, color: colors.textPrimary),
              label: Text('Export PDF', style: TextStyle(color: colors.textPrimary)),
            ),
          ],
        ),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ScanVaultColors colors) {
    if (_document!.pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: colors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No pages yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add" below to get started.',
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ReorderableGridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _document!.pages.length,
      itemBuilder: (context, index) {
        return _PageTile(
          key: ValueKey(_document!.pages[index].id),
          documentId: widget.documentId,
          page: _document!.pages[index],
          pageNumber: index + 1,
          isSelected: _selectedIndices.contains(index),
          isMultiSelect: _isMultiSelect,
          colors: colors,
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
          return;
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

class _PageTile extends ConsumerWidget {
  const _PageTile({
    required this.documentId,
    required this.page,
    required this.pageNumber,
    required this.isSelected,
    required this.isMultiSelect,
    required this.colors,
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
  final ScanVaultColors colors;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isSelected ? colors.accentTeal : colors.glassBorder, 
          width: isSelected ? 3 : 1
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSelected ? 13 : 16),
        child: InkWell(
          onTap: onTap,
          onLongPress: isMultiSelect ? onLongPress : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: _PageThumbnail(documentId: documentId, page: page),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pageNumber',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              if (isMultiSelect)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onLongPress(),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colors.accentTeal;
                      }
                      return colors.bgSurface;
                    }),
                    checkColor: colors.bgBase,
                  ),
                ),
              if (!isMultiSelect)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                    onPressed: () => _showContextMenu(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
            ],
          ),
        ),
      ),
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
              title: const Text('Edit / Crop'),
              onTap: () {
                Navigator.of(context).pop();
                onTap(); // Reuse edit logic
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: ScanVaultTheme.error),
              title: const Text('Delete', style: TextStyle(color: ScanVaultTheme.error)),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ScanVaultTheme.error),
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

class _PageThumbnail extends ConsumerWidget {
  const _PageThumbnail({required this.documentId, required this.page});

  final String documentId;
  final DocPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);
    
    final placeholder = ColoredBox(
      color: colors.bgElevated,
      child: Center(
        child: Icon(
          Icons.insert_drive_file_outlined,
          size: 40,
          color: colors.textTertiary.withValues(alpha: 0.3),
        ),
      ),
    );

    final path = page.thumbPath ?? page.displayPath;

    final bytesAsync = ref.watch(docFileBytesProvider((
      docId: documentId,
      path: path,
      version: 0,
    )));

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
