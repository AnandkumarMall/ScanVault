import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/constants.dart';
import '../../app/providers.dart';
import '../../domain/models/document.dart';
import '../../domain/models/edit_params.dart';
import '../../domain/models/index_entry.dart';
import '../capture/camera_screen.dart';
import '../capture/import_source.dart';
import '../crop/crop_review_screen.dart';
import '../document/document_detail_screen.dart';
import '../enhance/enhance_screen.dart';
import '../auth/pin_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final indexAsync = ref.watch(documentIndexProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: indexAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => _ErrorBody(
                  message: '$err',
                  onRetry: () => ref.read(documentIndexProvider.notifier).refresh(),
                ),
                data: (entries) => CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (!_isSelectionMode)
                      SliverToBoxAdapter(
                        child: _buildToolsSection(context, ref),
                      ),
                    if (entries.isEmpty)
                      const SliverFillRemaining(
                        child: _EmptyLibrary(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final filteredEntries = entries.where((e) => e.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                              if (i >= filteredEntries.length) return null;
                              final entry = filteredEntries[i];
                              final isSelected = _selectedIds.contains(entry.id);
                              
                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 400 + (i * 50).clamp(0, 300)),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(opacity: value, child: child),
                                  );
                                },
                                child: _DocumentCard(
                                  entry: entry,
                                  isSelected: isSelected,
                                  isSelectionMode: _isSelectionMode,
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(entry.id);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DocumentDetailScreen(documentId: entry.id),
                                        ),
                                      );
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    _toggleSelection(entry.id);
                                  },
                                ),
                              );
                            },
                            childCount: entries.where((e) => e.name.toLowerCase().contains(_searchQuery.toLowerCase())).length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : InkWell(
              onTap: () => _startNewDocument(context, ref, null),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Text('New Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar(context, ref) : null,
    );
  }

  Widget _buildProfileMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      elevation: 4,
      position: PopupMenuPosition.under,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Icon(Icons.person_outline_rounded, size: 20),
      ),
      onSelected: (value) {
        if (value == 'disconnect') {
          ref.read(vaultConnectionProvider.notifier).disconnect();
        } else if (value == 'set_pin') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PinScreen(isSettingPin: true),
          )).then((_) => setState(() {}));
        } else if (value == 'remove_pin') {
          ref.read(vaultPrefsProvider).removePin().then((_) => setState(() {}));
        }
      },
      itemBuilder: (context) {
        final prefs = ref.read(vaultPrefsProvider);
        return [
          if (!prefs.hasPin)
            const PopupMenuItem(value: 'set_pin', child: Text('Set PIN Lock'))
          else
            const PopupMenuItem(value: 'remove_pin', child: Text('Remove PIN Lock')),
          const PopupMenuItem(value: 'disconnect', child: Text('Disconnect Vault')),
        ];
      },
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_isSelectionMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _clearSelection,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            Text('${_selectedIds.length} Selected', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Documents', style: theme.textTheme.headlineLarge?.copyWith(letterSpacing: -1, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Rescan Vault',
                    onPressed: () => ref.read(documentIndexProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                  const SizedBox(width: 8),
                  _buildProfileMenu(context, ref),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Tools',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ToolCard(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Import PDF',
                  color: const Color(0xFFF06292),
                  onTap: () => _startNewDocument(context, ref, 'pdf'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToolCard(
                  icon: Icons.photo_library_rounded,
                  title: 'Gallery',
                  color: const Color(0xFF4FC3F7),
                  onTap: () => _startNewDocument(context, ref, 'gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToolCard(
                  icon: Icons.camera_alt_rounded,
                  title: 'Scan',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => _startNewDocument(context, ref, 'camera'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomBar(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    if (_selectedIds.length == 1) {
      return BottomAppBar(
        color: theme.colorScheme.surfaceContainerHighest,
        elevation: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Rename',
              onPressed: () => _renameSelected(context, ref),
              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
            ),
            IconButton(
              tooltip: 'Share Images',
              onPressed: () => _exportSelectedImages(context, ref),
              icon: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
            ),
            IconButton(
              tooltip: 'Export PDF',
              onPressed: () => _exportSelectedPdf(context, ref),
              icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.onSurface),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _deleteSelected(context, ref),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      );
    }

    return BottomAppBar(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: () => _deleteSelected(context, ref),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton.icon(
            onPressed: () => _mergeSelected(context, ref),
            icon: Icon(Icons.merge_type_rounded, color: theme.colorScheme.primary),
            label: Text('Merge', style: TextStyle(color: theme.colorScheme.primary)),
          ),
          TextButton.icon(
            onPressed: () => _exportSelectedPdf(context, ref),
            icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.onSurface),
            label: Text('Export PDF', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref) async {
    final ids = _selectedIds.toList();
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Documents?'),
        content: Text('Are you sure you want to delete ${ids.length} document(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in ids) {
        await ref.read(documentIndexProvider.notifier).deleteDocument(id);
      }
      _clearSelection();
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${ids.length} document(s)')));
    }
  }

  Future<void> _mergeSelected(BuildContext context, WidgetRef ref) async {
    final ids = _selectedIds.toList();
    if (ids.length < 2) return;
    
    final name = await _promptName(context, 'Merged Document');
    if (name == null || !context.mounted) return;

    _showProcessing(context);
    try {
      final vault = ref.read(vaultRepositoryProvider);
      await vault.mergeDocuments(name, ids);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully merged ${ids.length} documents into "$name"')));
      ref.read(documentIndexProvider.notifier).refresh();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to merge: $e')));
    }
  }

  Future<void> _exportSelectedPdf(BuildContext context, WidgetRef ref) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    _showProcessing(context);
    try {
      final vault = ref.read(vaultRepositoryProvider);
      final exporter = ref.read(pdfExportServiceProvider);
      
      // Load all selected documents fully
      final docs = <Document>[];
      for (final id in ids) {
        final doc = await vault.readDocument(id);
        if (doc != null) docs.add(doc);
      }
      
      // Combine all pages into one temporary document for export
      final combinedPages = docs.expand((d) => d.pages).toList();
      final combinedDoc = Document(
        id: 'export_temp',
        name: ids.length == 1 ? docs.first.name : 'Exported_Documents',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: combinedPages,
      );

      final bytes = await exporter.exportPdf(document: combinedDoc, vault: vault);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      
      await Printing.sharePdf(bytes: bytes, filename: '${combinedDoc.name}.pdf');
      _clearSelection();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
    }
  }

  Future<void> _exportSelectedImages(BuildContext context, WidgetRef ref) async {
    final id = _selectedIds.single;
    _showProcessing(context);
    try {
      final vault = ref.read(vaultRepositoryProvider);
      final doc = await vault.readDocument(id);
      if (doc == null || doc.pages.isEmpty) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        return;
      }
      
      final files = <XFile>[];
      for (int i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        if (page.processedPath == null) continue;
        final bytes = await vault.readDocumentFile(id, page.processedPath!);
        if (bytes != null) {
          files.add(XFile.fromData(
            bytes,
            name: '${doc.name}_${i + 1}.jpg',
            mimeType: 'image/jpeg',
          ));
        }
      }
      
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (files.isNotEmpty) {
        await Share.shareXFiles(files, text: doc.name);
      }
      _clearSelection();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export images: $e')));
    }
  }

  Future<void> _renameSelected(BuildContext context, WidgetRef ref) async {
    final id = _selectedIds.single;
    final entries = ref.read(documentIndexProvider).valueOrNull ?? [];
    final currentEntry = entries.firstWhere((e) => e.id == id);
    
    final name = await _promptName(context, currentEntry.name);
    if (name == null || !context.mounted) return;

    _showProcessing(context);
    try {
      final vault = ref.read(vaultRepositoryProvider);
      await vault.renameDocument(id, name);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document renamed')));
      ref.read(documentIndexProvider.notifier).refresh();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to rename: $e')));
    }
  }

  Future<void> _startNewDocument(BuildContext context, WidgetRef ref, String? forceSource) async {
    List<Uint8List> images = [];
    
    if (forceSource == 'gallery') {
      images = await pickImagesFromGallery();
    } else if (forceSource == 'pdf') {
      images = await _pickAndRasterizePdf(context);
    } else {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const CameraCaptureScreen(),
          fullscreenDialog: true,
        ),
      );
      if (result == null || !context.mounted) return;

      if (result is List<Uint8List>) {
        images = result;
      } else if (result == 'gallery') {
        images = await pickImagesFromGallery();
      } else if (result == 'pdf') {
        images = await _pickAndRasterizePdf(context);
      }
    }
    
    if (images.isEmpty || !context.mounted) return;

    final edits = await Navigator.of(context).push<List<EditParams>>(
      MaterialPageRoute(
        builder: (_) => CropReviewScreen(
          images: images,
          processor: ref.read(cvProcessorProvider),
        ),
        fullscreenDialog: true,
      ),
    );
    if (edits == null || !context.mounted) return;

    final processor = ref.read(cvProcessorProvider);
    _showProcessing(context);
    final warped = <Uint8List>[];
    try {
      for (var i = 0; i < images.length; i++) {
        final warpParams = EditParams(
          corners: edits[i].corners,
          rotationQuarters: edits[i].rotationQuarters,
        );
        final page = await processor.processPage(images[i], warpParams);
        warped.add(page);
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preview error: $e')));
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final filtered = await Navigator.of(context).push<List<EditParams>>(
      MaterialPageRoute(
        builder: (_) => EnhanceScreen(
          title: 'Enhance',
          original: warped.first,
          elided: edits.first,
          processor: processor,
        ),
        fullscreenDialog: true,
      ),
    );
    if (filtered == null || !context.mounted) return;

    final allParams = <EditParams>[];
    final enhance = filtered.first;
    for (final edit in edits) {
      allParams.add(
        edit.copyWith(
          filter: enhance.filter,
          brightness: enhance.brightness,
          contrast: enhance.contrast,
          sharpness: enhance.sharpness,
        ),
      );
    }

    final name = await _promptName(context, defaultScanName(DateTime.now()));
    if (name == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    _showProcessing(context);
    try {
      await ref
          .read(documentIndexProvider.notifier)
          .createScannedDocument(name, images, allParams);
      if (context.mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Saved "$name" - ${images.length} page${images.length == 1 ? '' : 's'}'),
      ));
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
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
              Text('Processing pages…'),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this document'),
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
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<List<Uint8List>> _pickAndRasterizePdf(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return [];

    _showProcessing(context);
    try {
      final pdfDoc = await PdfDocument.openFile(result.files.single.path!);
      final images = <Uint8List>[];
      for (final page in pdfDoc.pages) {
        final image = await page.render(
          width: (page.width * 1.5).toInt(),
          height: (page.height * 1.5).toInt(),
        );
        if (image != null) {
          final uiImage = await image.createImage();
          final byteData = await uiImage.toByteData();
          if (byteData != null) {
            final rawBytes = byteData.buffer.asUint8List();
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
      pdfDoc.dispose();
      if (!context.mounted) return [];
      Navigator.of(context).pop();
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
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 80, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Your vault is empty', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Scan a document or import files to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({
    required this.entry,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final IndexEntry entry;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Hero(
                    tag: 'cover_${entry.id}',
                    child: _CoverThumbnail(entry: entry),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(entry.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.file_copy_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.pageCount} page${entry.pageCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                    size: 24,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: onLongPress,
                  color: theme.colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverThumbnail extends ConsumerWidget {
  const _CoverThumbnail({required this.entry});

  final IndexEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );

    final cover = entry.coverPath;
    if (cover == null) return placeholder;

    final bytesAsync = ref.watch(docFileBytesProvider((
      docId: entry.id,
      path: cover,
      version: entry.updatedAt.millisecondsSinceEpoch,
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

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
