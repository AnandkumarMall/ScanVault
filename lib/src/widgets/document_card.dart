
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/models/index_entry.dart';
import '../app/theme.dart';

class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final IndexEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = entry.updatedAt;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: ScanVaultTheme.paperWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D1A3A3A),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: entry.coverPath != null
                        ? _buildCover(ref, entry.id, entry.coverPath!, theme)
                        : _buildPlaceholder(theme),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${entry.pageCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(WidgetRef ref, String docId, String coverPath, ThemeData theme) {
    final bytesAsync = ref.watch(docFileBytesProvider((
      docId: docId,
      path: coverPath,
      version: 0,
    )));

    return bytesAsync.when(
      loading: () => _buildPlaceholder(theme),
      error: (_, __) => _buildPlaceholder(theme),
      data: (bytes) => bytes == null
          ? _buildPlaceholder(theme)
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: 300,
            ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: ScanVaultTheme.foldTan.withValues(alpha: 0.3),
      child: Center(
        child: Icon(Icons.description_outlined, color: ScanVaultTheme.warmGray.withValues(alpha: 0.5), size: 32),
      ),
    );
  }
}
