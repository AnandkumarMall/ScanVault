import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/providers.dart';
import '../../domain/models/edit_params.dart';
import '../../domain/models/index_entry.dart';
import '../capture/camera_screen.dart';
import '../capture/import_source.dart';
import '../crop/crop_review_screen.dart';

/// The document library — a grid of document cards (PLAN.md §Document
/// Management). In Phase 1 the grid is empty and the FAB creates a blank
/// document; capture/import land in Phase 2.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexAsync = ref.watch(documentIndexProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          IconButton(
            tooltip: 'Rescan Vault',
            onPressed: () =>
                ref.read(documentIndexProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'disconnect') {
                ref.read(vaultConnectionProvider.notifier).disconnect();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'disconnect',
                child: Text('Disconnect Vault'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewDocument(context, ref),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New scan'),
      ),
      body: indexAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBody(
          message: '$err',
          onRetry: () => ref.read(documentIndexProvider.notifier).refresh(),
        ),
        data: (entries) => entries.isEmpty
            ? const _EmptyLibrary()
            : _DocumentGrid(entries: entries),
      ),
    );
  }

  /// Lets the user choose a capture source, gathers page images, names the
  /// document, and creates it (PLAN.md §2 — fast path is Camera → save).
  Future<void> _startNewDocument(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<_CaptureSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scan with camera'),
              onTap: () =>
                  Navigator.of(context).pop(_CaptureSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Import from gallery'),
              onTap: () =>
                  Navigator.of(context).pop(_CaptureSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final List<Uint8List> images;
    switch (source) {
      case _CaptureSource.camera:
        images = await Navigator.of(context).push<List<Uint8List>>(
              MaterialPageRoute(
                builder: (_) => const CameraCaptureScreen(),
                fullscreenDialog: true,
              ),
            ) ??
            const [];
      case _CaptureSource.gallery:
        images = await pickImagesFromGallery();
    }
    if (images.isEmpty || !context.mounted) return;

    // Detect & crop each page (Phase 3) before naming/saving.
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

    final name = await _promptName(context, defaultScanName(DateTime.now()));
    if (name == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    _showProcessing(context);
    try {
      await ref
          .read(documentIndexProvider.notifier)
          .createScannedDocument(name, images, edits);
      if (context.mounted) Navigator.of(context).pop(); // dismiss progress
      messenger.showSnackBar(SnackBar(
        content: Text('Saved "$name" · ${images.length} '
            'page${images.length == 1 ? '' : 's'}'),
      ));
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  /// A blocking, non-dismissible progress dialog shown while pages are warped
  /// and encoded (full-resolution OpenCV work can take a moment per page).
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
}

/// Where a new document's pages come from.
enum _CaptureSource { camera, gallery }

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
            Icon(Icons.description_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No documents yet',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Tap “New document” to get started.',
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

class _DocumentGrid extends ConsumerWidget {
  const _DocumentGrid({required this.entries});

  final List<IndexEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(documentIndexProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) => _DocumentCard(entry: entries[i]),
      ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.entry});

  final IndexEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _showActions(context, ref),
        onTap: () {}, // Document detail screen arrives in Phase 5.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _CoverThumbnail(entry: entry)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.pageCount} page${entry.pageCount == 1 ? '' : 's'} · '
                    '${_formatDate(entry.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      await ref
          .read(documentIndexProvider.notifier)
          .deleteDocument(entry.id);
    }
  }
}

/// The cover image of a document card. Falls back to a placeholder icon while
/// loading, on error, or when the document has no pages yet.
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
          Icons.insert_drive_file_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
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
              gaplessPlayback: true,
            ),
    );
  }
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

/// Minimal local date formatting (avoids the intl dependency for Phase 1).
String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
