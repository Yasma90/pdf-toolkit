import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';

// Providers
final mergeFileServiceProvider = Provider((ref) => FileService());
final mergePdfServiceProvider = Provider((ref) => PdfService());

final selectedFilesProvider = StateProvider<List<PdfFile>>((ref) => []);
final mergeStateProvider = StateProvider<MergeState>(
  (ref) => const MergeState.idle(),
);

// State classes
sealed class MergeState {
  const MergeState();
  const factory MergeState.idle() = MergeIdleState;
  const factory MergeState.processing(double progress, String? step) =
      MergeProcessingState;
  const factory MergeState.success(MergeResult result) = MergeSuccessState;
  const factory MergeState.error(String message) = MergeErrorState;
}

class MergeIdleState extends MergeState {
  const MergeIdleState();
}

class MergeProcessingState extends MergeState {
  final double progress;
  final String? step;
  const MergeProcessingState(this.progress, this.step);
}

class MergeSuccessState extends MergeState {
  final MergeResult result;
  const MergeSuccessState(this.result);
}

class MergeErrorState extends MergeState {
  final String message;
  const MergeErrorState(this.message);
}

class MergeScreen extends ConsumerWidget {
  const MergeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFiles = ref.watch(selectedFilesProvider);
    final state = ref.watch(mergeStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (selectedFiles.isNotEmpty && state is MergeIdleState)
            TextButton.icon(
              onPressed: () => _clearAll(ref),
              icon: const Icon(Icons.clear_all, size: 20),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state is MergeProcessingState
                  ? _buildProcessingView(state)
                  : state is MergeSuccessState
                      ? _buildSuccessView(context, ref, state)
                      : state is MergeErrorState
                          ? _buildErrorView(context, ref, state)
                          : _buildFileList(context, ref, selectedFiles),
            ),

            // Bottom action bar
            if (state is MergeIdleState)
              _buildBottomBar(context, ref, selectedFiles),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(
    BuildContext context,
    WidgetRef ref,
    List<PdfFile> files,
  ) {
    if (files.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      onReorder: (oldIndex, newIndex) {
        final list = [...files];
        if (newIndex > oldIndex) newIndex--;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        ref.read(selectedFilesProvider.notifier).state = list;
      },
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileListItem(
          key: ValueKey(file.filePath),
          file: file,
          index: index,
          onRemove: () {
            final list = [...files];
            list.removeAt(index);
            ref.read(selectedFilesProvider.notifier).state = list;
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.mergeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.merge_type,
                size: 64,
                color: AppColors.mergeColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDFs to Merge',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add at least 2 PDF files to combine them into one document',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _addFiles(ref),
              icon: const Icon(Icons.add),
              label: const Text('Add PDF Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mergeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView(MergeProcessingState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ProgressCard(
          progress: state.progress,
          currentStep: state.step,
          title: 'Merging PDFs',
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    WidgetRef ref,
    MergeSuccessState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ResultCard(
          success: true,
          title: 'Merge Complete!',
          subtitle: 'Your PDFs have been merged successfully',
          stats: [
            ResultStat(
              label: 'Files Merged',
              value: '${state.result.filesCount}',
            ),
            ResultStat(
              label: 'Total Pages',
              value: '${state.result.totalPages}',
            ),
            ResultStat(
              label: 'Output Size',
              value: _formatSize(state.result.outputSize),
            ),
          ],
          onPrimaryAction: () => _shareResult(ref, state.result.outputPath),
          primaryActionText: 'Share',
          onSecondaryAction: () => _reset(ref),
          secondaryActionText: 'Merge More',
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    MergeErrorState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ResultCard(
          success: false,
          title: 'Merge Failed',
          subtitle: state.message,
          onPrimaryAction: () => _reset(ref),
          primaryActionText: 'Try Again',
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    List<PdfFile> files,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addFiles(ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Files'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: files.length >= 2
                    ? () => _merge(context, ref, files)
                    : null,
                icon: const Icon(Icons.merge_type),
                label: Text('Merge (${files.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mergeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFiles(WidgetRef ref) async {
    final fileService = ref.read(mergeFileServiceProvider);
    final newFiles = await fileService.pickPdfFiles(multiple: true);
    if (newFiles.isNotEmpty) {
      final currentFiles = ref.read(selectedFilesProvider);
      ref.read(selectedFilesProvider.notifier).state = [
        ...currentFiles,
        ...newFiles,
      ];
    }
  }

  Future<void> _merge(
    BuildContext context,
    WidgetRef ref,
    List<PdfFile> files,
  ) async {
    final fileService = ref.read(mergeFileServiceProvider);
    final pdfService = ref.read(mergePdfServiceProvider);

    final outputPath = await fileService.generateOutputPath(
      inputPath: files.first.filePath,
      suffix: '_merged',
    );

    final result = await pdfService.mergePdfs(
      inputPaths: files.map((f) => f.filePath).toList(),
      outputPath: outputPath,
      onProgress: (progress, step) {
        ref.read(mergeStateProvider.notifier).state =
            MergeState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<MergeResult>) {
      ref.read(mergeStateProvider.notifier).state =
          MergeState.success(result.data);
    } else if (result is OperationFailure<MergeResult>) {
      ref.read(mergeStateProvider.notifier).state =
          MergeState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, String outputPath) async {
    final fileService = ref.read(mergeFileServiceProvider);
    await fileService.shareFile(outputPath);
  }

  void _clearAll(WidgetRef ref) {
    ref.read(selectedFilesProvider.notifier).state = [];
  }

  void _reset(WidgetRef ref) {
    ref.read(selectedFilesProvider.notifier).state = [];
    ref.read(mergeStateProvider.notifier).state = const MergeState.idle();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _FileListItem extends StatelessWidget {
  final PdfFile file;
  final int index;
  final VoidCallback onRemove;

  const _FileListItem({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.mergeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.mergeColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        title: Text(
          file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        subtitle: Text(
          file.formattedSize,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onRemove,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }
}
