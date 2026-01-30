import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/tool_card.dart';
import 'package:pdf_toolkit/features/compress/compress_screen.dart';
import 'package:pdf_toolkit/features/merge/merge_screen.dart';
import 'package:pdf_toolkit/features/split/split_screen.dart';
import 'package:pdf_toolkit/features/convert/convert_screen.dart';
import 'package:pdf_toolkit/features/protect/protect_screen.dart';
import 'package:pdf_toolkit/features/extract/extract_screen.dart';
import 'package:pdf_toolkit/features/settings/settings_screen.dart';
import 'package:pdf_toolkit/core/providers/recent_files_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final recentFiles = ref.watch(recentFilesProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PDF Toolkit',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'All-in-one PDF solution',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _navigateTo(context, const SettingsScreen()),
                          icon: const Icon(Icons.settings_outlined),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'What would you like to do?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Tools Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 1.2 : 1.0,
                ),
                delegate: SliverChildListDelegate([
                  ToolCard(
                    title: 'Compress',
                    subtitle: 'Reduce file size',
                    icon: Icons.compress,
                    color: AppColors.compressColor,
                    onTap: () => _navigateTo(context, const CompressScreen()),
                  ),
                  ToolCard(
                    title: 'Merge',
                    subtitle: 'Combine PDFs',
                    icon: Icons.merge_type,
                    color: AppColors.mergeColor,
                    onTap: () => _navigateTo(context, const MergeScreen()),
                  ),
                  ToolCard(
                    title: 'Split',
                    subtitle: 'Divide PDF',
                    icon: Icons.call_split,
                    color: AppColors.splitColor,
                    onTap: () => _navigateTo(context, const SplitScreen()),
                  ),
                  ToolCard(
                    title: 'Convert',
                    subtitle: 'PDF to Image',
                    icon: Icons.transform,
                    color: AppColors.convertColor,
                    onTap: () => _navigateTo(context, const ConvertScreen()),
                  ),
                  ToolCard(
                    title: 'Protect',
                    subtitle: 'Add password',
                    icon: Icons.lock_outline,
                    color: AppColors.protectColor,
                    onTap: () => _navigateTo(context, const ProtectScreen()),
                  ),
                  ToolCard(
                    title: 'Extract',
                    subtitle: 'Get pages',
                    icon: Icons.content_cut,
                    color: AppColors.extractColor,
                    onTap: () => _navigateTo(context, const ExtractScreen()),
                  ),
                ]),
              ),
            ),

            // Recent Files Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Files',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (recentFiles.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              ref.read(recentFilesProvider.notifier).clearAll();
                            },
                            child: const Text('Clear All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (recentFiles.isEmpty)
                      const RecentFilesPlaceholder()
                    else
                      RecentFilesList(files: recentFiles),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class RecentFilesPlaceholder extends StatelessWidget {
  const RecentFilesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent files',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recently processed PDFs will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class RecentFilesList extends StatelessWidget {
  final List<RecentFileEntry> files;

  const RecentFilesList({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: files.take(5).map((file) => _RecentFileItem(file: file)).toList(),
    );
  }
}

class _RecentFileItem extends StatelessWidget {
  final RecentFileEntry file;

  const _RecentFileItem({required this.file});

  Color _getOperationColor() {
    switch (file.operation.toLowerCase()) {
      case 'compress':
        return AppColors.compressColor;
      case 'merge':
        return AppColors.mergeColor;
      case 'split':
        return AppColors.splitColor;
      case 'convert':
        return AppColors.convertColor;
      case 'protect':
        return AppColors.protectColor;
      case 'extract':
        return AppColors.extractColor;
      default:
        return AppColors.primary;
    }
  }

  IconData _getOperationIcon() {
    switch (file.operation.toLowerCase()) {
      case 'compress':
        return Icons.compress;
      case 'merge':
        return Icons.merge_type;
      case 'split':
        return Icons.call_split;
      case 'convert':
        return Icons.transform;
      case 'protect':
        return Icons.lock_outline;
      case 'extract':
        return Icons.content_cut;
      default:
        return Icons.picture_as_pdf;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getOperationColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getOperationIcon(), color: color, size: 24),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                file.operation,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              file.formattedSize,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              file.formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Could open file location or re-process
        },
      ),
    );
  }
}
