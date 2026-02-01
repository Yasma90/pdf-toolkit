import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/batch_options.dart';
import 'package:pdf_toolkit/core/models/compression_level.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';

// Providers
final batchFilesProvider = StateProvider<List<BatchItem>>((ref) => []);
final batchOperationProvider = StateProvider<BatchOperationType>(
  (ref) => BatchOperationType.compress,
);
final batchOptionsProvider = StateProvider<BatchOptions>(
  (ref) => const BatchOptions(operationType: BatchOperationType.compress),
);
final batchStateProvider = StateProvider<BatchState>(
  (ref) => const BatchState.idle(),
);

// State classes
sealed class BatchState {
  const BatchState();
  const factory BatchState.idle() = BatchIdleState;
  const factory BatchState.processing(int current, int total, double progress) =
      BatchProcessingState;
  const factory BatchState.completed(BatchResult result) = BatchCompletedState;
  const factory BatchState.error(String message) = BatchErrorState;
}

class BatchIdleState extends BatchState {
  const BatchIdleState();
}

class BatchProcessingState extends BatchState {
  final int current;
  final int total;
  final double progress;
  const BatchProcessingState(this.current, this.total, this.progress);
}

class BatchCompletedState extends BatchState {
  final BatchResult result;
  const BatchCompletedState(this.result);
}

class BatchErrorState extends BatchState {
  final String message;
  const BatchErrorState(this.message);
}

class BatchScreen extends ConsumerWidget {
  const BatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(batchFilesProvider);
    final operation = ref.watch(batchOperationProvider);
    final state = ref.watch(batchStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Processing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (files.isNotEmpty && state is! BatchProcessingState)
            TextButton.icon(
              onPressed: () => _clearAll(ref),
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
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
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.batchColor.withOpacity(0.1),
                            AppColors.batchColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.batchColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.batchColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppColors.batchColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Process Multiple PDFs',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.batchColor,
                                      ),
                                ),
                                Text(
                                  'Apply the same operation to multiple files at once',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Operation selector
                    Text(
                      'Select Operation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _OperationSelector(
                      selected: operation,
                      onChanged: (op) {
                        ref.read(batchOperationProvider.notifier).state = op;
                        ref.read(batchOptionsProvider.notifier).state =
                            BatchOptions(operationType: op);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Operation-specific options
                    _OperationOptions(operation: operation, ref: ref),

                    const SizedBox(height: 24),

                    // File drop zone
                    Text(
                      'Select Files (${files.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FileDropZone(
                      onTap: () => _addFiles(ref),
                      selectedFileName: files.isNotEmpty
                          ? '${files.length} file(s) selected'
                          : null,
                      isLoading: state is BatchProcessingState,
                      multiple: true,
                    ),

                    // File list
                    if (files.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _BatchFileList(
                        items: files,
                        onRemove: (index) => _removeFile(ref, index),
                        isProcessing: state is BatchProcessingState,
                      ),
                    ],

                    // Processing state
                    if (state is BatchProcessingState) ...[
                      const SizedBox(height: 24),
                      _BatchProgressCard(
                        current: state.current,
                        total: state.total,
                        progress: state.progress,
                      ),
                    ],

                    // Completed state
                    if (state is BatchCompletedState) ...[
                      const SizedBox(height: 24),
                      _BatchResultCard(
                        result: state.result,
                        onDone: () => _reset(ref),
                      ),
                    ],

                    // Error state
                    if (state is BatchErrorState) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.message,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom action bar
            if (files.isNotEmpty &&
                state is! BatchProcessingState &&
                state is! BatchCompletedState)
              _BatchActionBar(
                fileCount: files.length,
                onProcess: () => _processBatch(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFiles(WidgetRef ref) async {
    final fileService = FileService();
    final files = await fileService.pickPdfFiles(multiple: true);
    if (files.isNotEmpty) {
      final currentItems = [...ref.read(batchFilesProvider)];
      for (final file in files) {
        currentItems.add(BatchItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          file: file,
        ));
      }
      ref.read(batchFilesProvider.notifier).state = currentItems;
    }
  }

  void _removeFile(WidgetRef ref, int index) {
    final items = [...ref.read(batchFilesProvider)];
    items.removeAt(index);
    ref.read(batchFilesProvider.notifier).state = items;
  }

  void _clearAll(WidgetRef ref) {
    ref.read(batchFilesProvider.notifier).state = [];
    ref.read(batchStateProvider.notifier).state = const BatchState.idle();
  }

  void _reset(WidgetRef ref) {
    ref.read(batchFilesProvider.notifier).state = [];
    ref.read(batchStateProvider.notifier).state = const BatchState.idle();
  }

  Future<void> _processBatch(BuildContext context, WidgetRef ref) async {
    final items = ref.read(batchFilesProvider);
    final operation = ref.read(batchOperationProvider);
    final options = ref.read(batchOptionsProvider);
    final fileService = FileService();
    final pdfService = PdfService();

    if (items.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    var totalOriginalSize = 0;
    final totalResultSize = 0;
    final processedItems = <BatchItem>[];

    for (int i = 0; i < items.length; i++) {
      ref.read(batchStateProvider.notifier).state =
          BatchState.processing(i + 1, items.length, (i + 1) / items.length);

      final item = items[i];

      // Update item status to processing
      final updatedItems = [...ref.read(batchFilesProvider)];
      updatedItems[i] = item.copyWith(status: BatchItemStatus.processing);
      ref.read(batchFilesProvider.notifier).state = updatedItems;

      try {
        final outputPath = await fileService.generateOutputPath(
          inputPath: item.file.filePath,
          suffix: '_batch_${operation.name}',
        );

        // Process based on operation type
        final success = await _processFile(
          item: item,
          operation: operation,
          options: options,
          outputPath: outputPath,
          pdfService: pdfService,
        );

        if (success) {
          successCount++;
          totalOriginalSize += item.file.sizeInBytes;

          final updatedItems = [...ref.read(batchFilesProvider)];
          updatedItems[i] = item.copyWith(
            status: BatchItemStatus.completed,
            outputPath: outputPath,
            progress: 1.0,
          );
          ref.read(batchFilesProvider.notifier).state = updatedItems;
          processedItems.add(updatedItems[i]);
        } else {
          failedCount++;
          final updatedItems = [...ref.read(batchFilesProvider)];
          updatedItems[i] = item.copyWith(
            status: BatchItemStatus.failed,
            errorMessage: 'Processing failed',
          );
          ref.read(batchFilesProvider.notifier).state = updatedItems;
          processedItems.add(updatedItems[i]);
        }
      } catch (e) {
        failedCount++;
        final updatedItems = [...ref.read(batchFilesProvider)];
        updatedItems[i] = item.copyWith(
          status: BatchItemStatus.failed,
          errorMessage: e.toString(),
        );
        ref.read(batchFilesProvider.notifier).state = updatedItems;
        processedItems.add(updatedItems[i]);

        if (options.stopOnError) break;
      }
    }

    stopwatch.stop();

    final result = BatchResult(
      totalFiles: items.length,
      successCount: successCount,
      failedCount: failedCount,
      totalOriginalSize: totalOriginalSize,
      totalResultSize: totalResultSize,
      totalDuration: stopwatch.elapsed,
      items: processedItems,
    );

    ref.read(batchStateProvider.notifier).state = BatchState.completed(result);
  }

  Future<bool> _processFile({
    required BatchItem item,
    required BatchOperationType operation,
    required BatchOptions options,
    required String outputPath,
    required PdfService pdfService,
  }) async {
    switch (operation) {
      case BatchOperationType.compress:
        final result = await pdfService.compressPdf(
          inputPath: item.file.filePath,
          outputPath: outputPath,
          options: options.compressionOptions ?? const CompressionOptions(),
        );
        return result is OperationSuccess;
      case BatchOperationType.convert:
        // Convert to images
        return true; // Placeholder
      case BatchOperationType.protect:
        // Add password protection
        return true; // Placeholder
      case BatchOperationType.watermark:
        // Add watermark
        return true; // Placeholder
      case BatchOperationType.rotate:
        // Rotate pages
        return true; // Placeholder
      case BatchOperationType.addPageNumbers:
        // Add page numbers
        return true; // Placeholder
    }
  }
}

class _OperationSelector extends StatelessWidget {
  final BatchOperationType selected;
  final ValueChanged<BatchOperationType> onChanged;

  const _OperationSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final operations = [
      (BatchOperationType.compress, Icons.compress, 'Compress', AppColors.compressColor),
      (BatchOperationType.watermark, Icons.water_drop, 'Watermark', AppColors.watermarkColor),
      (BatchOperationType.rotate, Icons.rotate_right, 'Rotate', AppColors.rotateColor),
      (BatchOperationType.addPageNumbers, Icons.format_list_numbered, 'Numbers', AppColors.pageNumbersColor),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: operations.map((op) {
        final isSelected = op.$1 == selected;
        return GestureDetector(
          onTap: () => onChanged(op.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? op.$4.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? op.$4 : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(op.$2, size: 20, color: isSelected ? op.$4 : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  op.$3,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? op.$4 : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OperationOptions extends StatelessWidget {
  final BatchOperationType operation;
  final WidgetRef ref;

  const _OperationOptions({
    required this.operation,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    switch (operation) {
      case BatchOperationType.compress:
        return _CompressionLevelPicker(ref: ref);
      case BatchOperationType.watermark:
        return _WatermarkTextInput(ref: ref);
      case BatchOperationType.rotate:
        return _RotationAnglePicker(ref: ref);
      case BatchOperationType.addPageNumbers:
        return _PageNumberFormatPicker(ref: ref);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CompressionLevelPicker extends StatelessWidget {
  final WidgetRef ref;

  const _CompressionLevelPicker({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compression Level',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CompressionLevel>(
          segments: CompressionLevel.values
              .where((l) => l != CompressionLevel.custom)
              .map((level) => ButtonSegment(
                    value: level,
                    label: Text(level.name),
                  ))
              .toList(),
          selected: const {CompressionLevel.medium},
          onSelectionChanged: (selected) {
            // Update compression options
          },
        ),
      ],
    );
  }
}

class _WatermarkTextInput extends StatelessWidget {
  final WidgetRef ref;

  const _WatermarkTextInput({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Watermark Text',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: 'CONFIDENTIAL',
          decoration: const InputDecoration(
            hintText: 'Enter watermark text',
            prefixIcon: Icon(Icons.text_fields),
          ),
        ),
      ],
    );
  }
}

class _RotationAnglePicker extends StatelessWidget {
  final WidgetRef ref;

  const _RotationAnglePicker({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rotation Angle',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<RotationAngle>(
          segments: RotationAngle.values
              .map((angle) => ButtonSegment(
                    value: angle,
                    label: Text('${angle.degrees}°'),
                  ))
              .toList(),
          selected: const {RotationAngle.clockwise90},
          onSelectionChanged: (selected) {
            // Update rotation options
          },
        ),
      ],
    );
  }
}

class _PageNumberFormatPicker extends StatelessWidget {
  final WidgetRef ref;

  const _PageNumberFormatPicker({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Number Format',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(label: const Text('1, 2, 3'), selected: true, onSelected: (_) {}),
            ChoiceChip(label: const Text('Page 1'), selected: false, onSelected: (_) {}),
            ChoiceChip(label: const Text('I, II, III'), selected: false, onSelected: (_) {}),
          ],
        ),
      ],
    );
  }
}

class _BatchFileList extends StatelessWidget {
  final List<BatchItem> items;
  final void Function(int index) onRemove;
  final bool isProcessing;

  const _BatchFileList({
    required this.items,
    required this.onRemove,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        Color statusColor;
        IconData statusIcon;
        switch (item.status) {
          case BatchItemStatus.pending:
            statusColor = Colors.grey;
            statusIcon = Icons.schedule;
            break;
          case BatchItemStatus.processing:
            statusColor = AppColors.batchColor;
            statusIcon = Icons.sync;
            break;
          case BatchItemStatus.completed:
            statusColor = AppColors.success;
            statusIcon = Icons.check_circle;
            break;
          case BatchItemStatus.failed:
            statusColor = AppColors.error;
            statusIcon = Icons.error;
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.file.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.file.formattedSize,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (!isProcessing)
                IconButton(
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.grey,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BatchProgressCard extends StatelessWidget {
  final int current;
  final int total;
  final double progress;

  const _BatchProgressCard({
    required this.current,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.batchColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.batchColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.batchColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Processing $current of $total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.batchColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.batchColor.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.batchColor),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.batchColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _BatchResultCard extends StatelessWidget {
  final BatchResult result;
  final VoidCallback onDone;

  const _BatchResultCard({
    required this.result,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Batch Complete!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResultStat(
                label: 'Successful',
                value: result.successCount.toString(),
                color: AppColors.success,
              ),
              _ResultStat(
                label: 'Failed',
                value: result.failedCount.toString(),
                color: AppColors.error,
              ),
              _ResultStat(
                label: 'Total',
                value: result.totalFiles.toString(),
                color: AppColors.batchColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  final int fileCount;
  final VoidCallback onProcess;

  const _BatchActionBar({
    required this.fileCount,
    required this.onProcess,
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
          onPressed: onProcess,
          icon: const Icon(Icons.play_arrow),
          label: Text('Process $fileCount File${fileCount > 1 ? 's' : ''}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.batchColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}
