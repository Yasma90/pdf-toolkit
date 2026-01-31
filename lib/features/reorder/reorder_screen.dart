import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_processor.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';
import 'package:pdf_toolkit/core/providers/recent_files_provider.dart';

// Providers
final reorderFileProvider = StateProvider<PdfFile?>((ref) => null);
final reorderPageCountProvider = StateProvider<int>((ref) => 0);
final reorderPageOrderProvider = StateProvider<List<int>>((ref) => []);
final reorderPagesToDeleteProvider = StateProvider<Set<int>>((ref) => {});
final reorderStateProvider = StateProvider<ReorderState>(
  (ref) => const ReorderState.idle(),
);

// State classes
sealed class ReorderState {
  const ReorderState();
  const factory ReorderState.idle() = ReorderIdleState;
  const factory ReorderState.loading() = ReorderLoadingState;
  const factory ReorderState.ready(int pageCount) = ReorderReadyState;
  const factory ReorderState.processing(double progress, String? step) =
      ReorderProcessingState;
  const factory ReorderState.success(String outputPath) = ReorderSuccessState;
  const factory ReorderState.error(String message) = ReorderErrorState;
}

class ReorderIdleState extends ReorderState {
  const ReorderIdleState();
}

class ReorderLoadingState extends ReorderState {
  const ReorderLoadingState();
}

class ReorderReadyState extends ReorderState {
  final int pageCount;
  const ReorderReadyState(this.pageCount);
}

class ReorderProcessingState extends ReorderState {
  final double progress;
  final String? step;
  const ReorderProcessingState(this.progress, this.step);
}

class ReorderSuccessState extends ReorderState {
  final String outputPath;
  const ReorderSuccessState(this.outputPath);
}

class ReorderErrorState extends ReorderState {
  final String message;
  const ReorderErrorState(this.message);
}

class ReorderScreen extends ConsumerWidget {
  const ReorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(reorderFileProvider);
    final pageOrder = ref.watch(reorderPageOrderProvider);
    final pagesToDelete = ref.watch(reorderPagesToDeleteProvider);
    final state = ref.watch(reorderStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder & Delete Pages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (state is ReorderReadyState)
            TextButton.icon(
              onPressed: () => _resetOrder(ref, state.pageCount),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // File selection
                    FileDropZone(
                      onTap: () => _selectFile(ref),
                      selectedFileName: selectedFile?.fileName,
                      fileSize: selectedFile?.formattedSize,
                      onClear: selectedFile != null
                          ? () => _clearFile(ref)
                          : null,
                      isLoading: state is ReorderLoadingState ||
                          state is ReorderProcessingState,
                    ),

                    if (state is ReorderReadyState) ...[
                      const SizedBox(height: 24),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.reorderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.reorderColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.touch_app,
                              color: AppColors.reorderColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Drag pages to reorder. Tap the delete icon to remove pages.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.reorderColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Page count info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pages',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Row(
                            children: [
                              _StatChip(
                                label: 'Total',
                                value: state.pageCount.toString(),
                                color: AppColors.reorderColor,
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                label: 'To Delete',
                                value: pagesToDelete.length.toString(),
                                color: AppColors.unlockColor,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Reorderable page list
                      _ReorderablePageList(
                        pageOrder: pageOrder,
                        pagesToDelete: pagesToDelete,
                        onReorder: (oldIndex, newIndex) {
                          _reorderPage(ref, oldIndex, newIndex);
                        },
                        onToggleDelete: (pageIndex) {
                          _toggleDeletePage(ref, pageIndex);
                        },
                      ),
                    ],

                    // Processing state
                    if (state is ReorderProcessingState) ...[
                      const SizedBox(height: 32),
                      ProgressCard(
                        progress: state.progress,
                        currentStep: state.step,
                        title: 'Processing PDF',
                      ),
                    ],

                    // Success state
                    if (state is ReorderSuccessState) ...[
                      const SizedBox(height: 32),
                      ResultCard(
                        success: true,
                        title: 'PDF Updated!',
                        subtitle: 'Pages have been reordered/deleted',
                        onTertiaryAction: () => _saveResult(context, state.outputPath),
                        tertiaryActionText: 'Save',
                        onPrimaryAction: () => _shareResult(ref, state.outputPath),
                        primaryActionText: 'Share',
                        onSecondaryAction: () => _clearFile(ref),
                        secondaryActionText: 'Process Another',
                      ),
                    ],

                    // Error state
                    if (state is ReorderErrorState) ...[
                      const SizedBox(height: 32),
                      ResultCard(
                        success: false,
                        title: 'Processing Failed',
                        subtitle: state.message,
                        onPrimaryAction: () {
                          ref.read(reorderStateProvider.notifier).state =
                              const ReorderState.idle();
                        },
                        primaryActionText: 'Try Again',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom action bar
            if (state is ReorderReadyState)
              _BottomActionBar(
                hasChanges: _hasChanges(pageOrder, pagesToDelete, state.pageCount),
                onApply: () => _applyChanges(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasChanges(List<int> order, Set<int> toDelete, int pageCount) {
    if (toDelete.isNotEmpty) return true;
    for (int i = 0; i < order.length; i++) {
      if (order[i] != i) return true;
    }
    return false;
  }

  Future<void> _selectFile(WidgetRef ref) async {
    final fileService = FileService();
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(reorderFileProvider.notifier).state = files.first;
      ref.read(reorderStateProvider.notifier).state = const ReorderState.loading();

      // Get page count (this would ideally come from PDF service)
      // For now, simulate loading with a default
      await Future.delayed(const Duration(milliseconds: 500));

      // In real implementation, read actual page count from PDF
      const pageCount = 10; // Placeholder - should read from PDF

      ref.read(reorderPageCountProvider.notifier).state = pageCount;
      ref.read(reorderPageOrderProvider.notifier).state =
          List.generate(pageCount, (i) => i);
      ref.read(reorderPagesToDeleteProvider.notifier).state = {};
      ref.read(reorderStateProvider.notifier).state =
          ReorderState.ready(pageCount);
    }
  }

  void _clearFile(WidgetRef ref) {
    ref.read(reorderFileProvider.notifier).state = null;
    ref.read(reorderPageOrderProvider.notifier).state = [];
    ref.read(reorderPagesToDeleteProvider.notifier).state = {};
    ref.read(reorderStateProvider.notifier).state = const ReorderState.idle();
  }

  void _resetOrder(WidgetRef ref, int pageCount) {
    ref.read(reorderPageOrderProvider.notifier).state =
        List.generate(pageCount, (i) => i);
    ref.read(reorderPagesToDeleteProvider.notifier).state = {};
  }

  void _reorderPage(WidgetRef ref, int oldIndex, int newIndex) {
    final order = [...ref.read(reorderPageOrderProvider)];
    if (newIndex > oldIndex) newIndex--;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    ref.read(reorderPageOrderProvider.notifier).state = order;
  }

  void _toggleDeletePage(WidgetRef ref, int pageIndex) {
    final toDelete = {...ref.read(reorderPagesToDeleteProvider)};
    if (toDelete.contains(pageIndex)) {
      toDelete.remove(pageIndex);
    } else {
      toDelete.add(pageIndex);
    }
    ref.read(reorderPagesToDeleteProvider.notifier).state = toDelete;
  }

  Future<void> _applyChanges(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(reorderFileProvider);
    final pageOrder = ref.read(reorderPageOrderProvider);
    final pagesToDelete = ref.read(reorderPagesToDeleteProvider);
    final fileService = FileService();
    final processor = PdfProcessor();

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_reordered',
    );

    // Filter out pages to delete and maintain new order
    final finalOrder = pageOrder
        .where((page) => !pagesToDelete.contains(page))
        .toList();

    if (finalOrder.isEmpty) {
      ref.read(reorderStateProvider.notifier).state =
          const ReorderState.error('Cannot delete all pages');
      return;
    }

    // If there are pages to delete, use deletePages first, then reorder
    // For simplicity, we'll use reorderPages which handles both
    final result = await processor.reorderPages(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      newOrder: finalOrder,
      onProgress: (progress, step) {
        ref.read(reorderStateProvider.notifier).state =
            ReorderState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<String>) {
      ref.read(reorderStateProvider.notifier).state =
          ReorderState.success(result.data);

      // Add to recent files
      ref.read(recentFilesProvider.notifier).addEntry(
        filePath: result.data,
        operation: 'Reorder',
      );
    } else if (result is OperationFailure<String>) {
      ref.read(reorderStateProvider.notifier).state =
          ReorderState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, String outputPath) async {
    final fileService = FileService();
    await fileService.shareFile(outputPath);
  }

  Future<void> _saveResult(BuildContext context, String outputPath) async {
    final fileService = FileService();
    final savedPath = await fileService.saveFileAs(outputPath);

    if (savedPath != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to: $savedPath'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReorderablePageList extends StatelessWidget {
  final List<int> pageOrder;
  final Set<int> pagesToDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int pageIndex) onToggleDelete;

  const _ReorderablePageList({
    required this.pageOrder,
    required this.pagesToDelete,
    required this.onReorder,
    required this.onToggleDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pageOrder.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final pageIndex = pageOrder[index];
        final isMarkedForDelete = pagesToDelete.contains(pageIndex);

        return _PageItem(
          key: ValueKey(pageIndex),
          pageNumber: pageIndex + 1,
          currentIndex: index + 1,
          isMarkedForDelete: isMarkedForDelete,
          onToggleDelete: () => onToggleDelete(pageIndex),
        );
      },
    );
  }
}

class _PageItem extends StatelessWidget {
  final int pageNumber;
  final int currentIndex;
  final bool isMarkedForDelete;
  final VoidCallback onToggleDelete;

  const _PageItem({
    super.key,
    required this.pageNumber,
    required this.currentIndex,
    required this.isMarkedForDelete,
    required this.onToggleDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMarkedForDelete
            ? AppColors.unlockColor.withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMarkedForDelete
              ? AppColors.unlockColor
              : Theme.of(context).dividerColor,
          width: isMarkedForDelete ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: isMarkedForDelete
                    ? Colors.grey.shade300
                    : AppColors.reorderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isMarkedForDelete
                      ? Colors.grey.shade400
                      : AppColors.reorderColor.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Text(
                  pageNumber.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMarkedForDelete
                        ? Colors.grey.shade500
                        : AppColors.reorderColor,
                    decoration:
                        isMarkedForDelete ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          'Page $pageNumber',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: isMarkedForDelete ? TextDecoration.lineThrough : null,
            color: isMarkedForDelete ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          isMarkedForDelete
              ? 'Will be deleted'
              : 'New position: $currentIndex',
          style: TextStyle(
            fontSize: 12,
            color: isMarkedForDelete ? AppColors.unlockColor : AppColors.textSecondary,
          ),
        ),
        trailing: IconButton(
          onPressed: onToggleDelete,
          icon: Icon(
            isMarkedForDelete ? Icons.restore : Icons.delete_outline,
            color: isMarkedForDelete ? AppColors.success : AppColors.unlockColor,
          ),
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool hasChanges;
  final VoidCallback onApply;

  const _BottomActionBar({
    required this.hasChanges,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: hasChanges ? onApply : null,
          icon: const Icon(Icons.check),
          label: const Text('Apply Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.reorderColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}
