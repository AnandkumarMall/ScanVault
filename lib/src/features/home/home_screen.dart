import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/index_entry.dart';
import '../document/document_detail_screen.dart';
import '../../widgets/document_card.dart';
import '../settings/settings_screen.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/glow_container.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum SortType { time, name }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SortType _sortType = SortType.time;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);
    final indexAsync = ref.watch(documentIndexProvider);
    final allDocs = indexAsync.valueOrNull ?? [];
    
    final docs = _searchQuery.isEmpty 
        ? List<IndexEntry>.from(allDocs)
        : allDocs.where((d) => d.name.toLowerCase().contains(_searchQuery)).toList();
        
    if (_sortType == SortType.time) {
      docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      docs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(documentIndexProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Vault', style: theme.textTheme.displayMedium),
                          const SizedBox(height: 4),
                          Text('${allDocs.length} documents · 100% offline', style: theme.textTheme.labelSmall),
                        ],
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.bgElevated,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.shield, color: colors.accentTeal, size: 20),
                          onPressed: _showShieldInfo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.bgElevated,
                      hintText: 'Search documents...',
                      hintStyle: TextStyle(color: colors.textTertiary),
                      prefixIcon: Icon(Icons.search, color: colors.textTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.glassBorder, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.glassBorder, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.accentTeal, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Recent Section
              if (indexAsync.isLoading && allDocs.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (docs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: colors.textTertiary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('Vault is empty', style: theme.textTheme.titleLarge?.copyWith(color: colors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Tap Scan below to add documents', style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Documents', style: theme.textTheme.titleMedium),
                        PopupMenuButton<SortType>(
                          initialValue: _sortType,
                          icon: Icon(Icons.sort, color: colors.textPrimary),
                          onSelected: (type) {
                            setState(() => _sortType = type);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: SortType.time,
                              child: Text('Sort by Time'),
                            ),
                            const PopupMenuItem(
                              value: SortType.name,
                              child: Text('Sort by Name'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 3 / 4,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = docs[index];
                        return DocumentCard(
                          entry: entry,
                          onTap: () => _openDocument(entry),
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for FAB
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: isDark ? GlowContainer(
        shape: BoxShape.circle,
        glowColor: colors.accentTeal.withValues(alpha: 0.2),
        blurRadius: 20,
        child: FloatingActionButton(
          onPressed: _startScan,
          backgroundColor: colors.accentTeal,
          foregroundColor: colors.bgBase,
          elevation: 0,
          child: const Icon(Icons.document_scanner_outlined),
        ),
      ) : FloatingActionButton.extended(
        onPressed: _startScan,
        backgroundColor: colors.accentTeal,
        foregroundColor: colors.bgBase,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 4,
      ),
      bottomNavigationBar: isDark ? GlassPanel(
        backgroundColor: colors.glassBg,
        borderColor: colors.glassBorder,
        borderRadius: 0,
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.folder_copy_rounded, color: colors.accentTeal),
                  onPressed: () {},
                ),
                const SizedBox(width: 48), // Space for FAB notch
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: colors.textTertiary),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ) : BottomAppBar(
        color: colors.bgSurface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.folder_copy_rounded, color: colors.textPrimary),
                onPressed: () {},
              ),
              const SizedBox(width: 48), // Space for FAB notch
              IconButton(
                icon: Icon(Icons.settings_outlined, color: colors.textSecondary),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShieldInfo() {
    final colors = ScanVaultColors(Theme.of(context).brightness == Brightness.dark);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield, color: colors.accentTeal),
            const SizedBox(width: 8),
            const Text('Security Status'),
          ],
        ),
        content: const Text('Your documents are encrypted and stored locally. ScanVault works 100% offline and never uploads your files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openDocument(IndexEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(documentId: entry.id),
      ),
    );
  }

  Future<void> _startScan() async {
    List<String> images = [];
    try {
      images = await CunningDocumentScanner.getPictures() ?? [];
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanner error: $e')));
      return;
    }
    
    if (images.isEmpty || !mounted) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '').split('.')[0];
    final defaultName = 'Document $timestamp';
    final name = await _promptName(context, defaultName);
    if (name == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    _showProcessing(context);
    try {
      final vault = ref.read(vaultRepositoryProvider);
      final doc = await vault.createDocument(name);
      await vault.addScannedPages(doc.id, images);
      
      if (!mounted) return;
      Navigator.of(context).pop(); 
      await ref.read(documentIndexProvider.notifier).refresh();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  void _showProcessing(BuildContext context) {
    final colors = ScanVaultColors(Theme.of(context).brightness == Brightness.dark);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: colors.accentTeal)),
              const SizedBox(width: 20),
              const Text('Processing pages…'),
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
          ElevatedButton(
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
