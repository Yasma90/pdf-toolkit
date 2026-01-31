import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/batch_options.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_processor.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';
import 'package:pdf_toolkit/core/providers/recent_files_provider.dart';

// Providers
final pageNumbersFileProvider = StateProvider<PdfFile?>((ref) => null);
final pageNumbersOptionsProvider = StateProvider<PageNumberOptions>(
  (ref) => const PageNumberOptions(),
);
final pageNumbersStateProvider = StateProvider<PageNumbersState>(
  (ref) => const PageNumbersState.idle(),
);

// State classes
sealed class PageNumbersState {
  const PageNumbersState();
  const factory PageNumbersState.idle() = PageNumbersIdleState;
  const factory PageNumbersState.processing(double progress, String? step) =
      PageNumbersProcessingState;
  const factory PageNumbersState.success(String outputPath) =
      PageNumbersSuccessState;
  const factory PageNumbersState.error(String message) = PageNumbersErrorState;
}

class PageNumbersIdleState extends PageNumbersState {
  const PageNumbersIdleState();
}

class PageNumbersProcessingState extends PageNumbersState {
  final double progress;
  final String? step;
  const PageNumbersProcessingState(this.progress, this.step);
}

class PageNumbersSuccessState extends PageNumbersState {
  final String outputPath;
  const PageNumbersSuccessState(this.outputPath);
}

class PageNumbersErrorState extends PageNumbersState {
  final String message;
  const PageNumbersErrorState(this.message);
}

class PageNumbersScreen extends ConsumerWidget {
  const PageNumbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(pageNumbersFileProvider);
    final options = ref.watch(pageNumbersOptionsProvider);
    final state = ref.watch(pageNumbersStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Page Numbers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
                    ? () => ref.read(pageNumbersFileProvider.notifier).state = null
                    : null,
                isLoading: state is PageNumbersProcessingState,
              ),

              if (selectedFile != null && state is! PageNumbersProcessingState) ...[
                const SizedBox(height: 32),

                // Format selection
                Text(
                  'Number Format',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _FormatSelector(
                  selected: options.format,
                  onChanged: (format) {
                    ref.read(pageNumbersOptionsProvider.notifier).state =
                        options.copyWith(format: format);
                  },
                ),

                const SizedBox(height: 24),

                // Position selection
                Text(
                  'Position',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _PositionSelector(
                  selected: options.position,
                  onChanged: (position) {
                    ref.read(pageNumbersOptionsProvider.notifier).state =
                        options.copyWith(position: position);
                  },
                ),

                const SizedBox(height: 24),

                // Preview
                _NumberPreview(options: options),

                const SizedBox(height: 24),

                // Options
                _OptionsSection(
                  options: options,
                  onChanged: (newOptions) {
                    ref.read(pageNumbersOptionsProvider.notifier).state = newOptions;
                  },
                ),

                const SizedBox(height: 32),

                // Add page numbers button
                ElevatedButton.icon(
                  onPressed: () => _addPageNumbers(context, ref),
                  icon: const Icon(Icons.format_list_numbered),
                  label: const Text('Add Page Numbers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pageNumbersColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is PageNumbersProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Adding Page Numbers',
                ),
              ],

              // Success state
              if (state is PageNumbersSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Page Numbers Added!',
                  subtitle: 'Your PDF now has page numbers',
                  onTertiaryAction: () => _saveResult(context, state.outputPath),
                  tertiaryActionText: 'Save',
                  onPrimaryAction: () => _shareResult(ref, state.outputPath),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Process Another',
                ),
              ],

              // Error state
              if (state is PageNumbersErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Failed',
                  subtitle: state.message,
                  onPrimaryAction: () => _reset(ref),
                  primaryActionText: 'Try Again',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectFile(WidgetRef ref) async {
    final fileService = FileService();
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(pageNumbersFileProvider.notifier).state = files.first;
      ref.read(pageNumbersStateProvider.notifier).state =
          const PageNumbersState.idle();
    }
  }

  Future<void> _addPageNumbers(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(pageNumbersFileProvider);
    final options = ref.read(pageNumbersOptionsProvider);
    final fileService = FileService();
    final processor = PdfProcessor();

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_numbered',
    );

    final result = await processor.addPageNumbers(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      options: options,
      onProgress: (progress, step) {
        ref.read(pageNumbersStateProvider.notifier).state =
            PageNumbersState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<String>) {
      ref.read(pageNumbersStateProvider.notifier).state =
          PageNumbersState.success(result.data);

      // Add to recent files
      ref.read(recentFilesProvider.notifier).addEntry(
        filePath: result.data,
        operation: 'Page Numbers',
      );
    } else if (result is OperationFailure<String>) {
      ref.read(pageNumbersStateProvider.notifier).state =
          PageNumbersState.error(result.error);
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

  void _reset(WidgetRef ref) {
    ref.read(pageNumbersFileProvider.notifier).state = null;
    ref.read(pageNumbersStateProvider.notifier).state =
        const PageNumbersState.idle();
  }
}

class _FormatSelector extends StatelessWidget {
  final PageNumberFormat selected;
  final ValueChanged<PageNumberFormat> onChanged;

  const _FormatSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final formats = [
      (PageNumberFormat.simple, '1, 2, 3', 'Simple'),
      (PageNumberFormat.withTotal, '1 / 10', 'With Total'),
      (PageNumberFormat.pageX, 'Page 1', 'Page X'),
      (PageNumberFormat.pageXOfY, 'Page 1 of 10', 'Page X of Y'),
      (PageNumberFormat.roman, 'I, II, III', 'Roman'),
      (PageNumberFormat.letter, 'A, B, C', 'Letter'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: formats.map((format) {
        final isSelected = format.$1 == selected;
        return GestureDetector(
          onTap: () => onChanged(format.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.pageNumbersColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppColors.pageNumbersColor
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  format.$2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.pageNumbersColor : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  format.$3,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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

class _PositionSelector extends StatelessWidget {
  final PageNumberPosition selected;
  final ValueChanged<PageNumberPosition> onChanged;

  const _PositionSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final positions = [
      [PageNumberPosition.topLeft, PageNumberPosition.topCenter, PageNumberPosition.topRight],
      [PageNumberPosition.bottomLeft, PageNumberPosition.bottomCenter, PageNumberPosition.bottomRight],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: positions[0].map((pos) => _PositionDot(
              position: pos,
              isSelected: selected == pos,
              onTap: () => onChanged(pos),
            )).toList(),
          ),
          // Page preview
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Icon(Icons.description_outlined, color: Colors.grey, size: 32),
            ),
          ),
          // Bottom row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: positions[1].map((pos) => _PositionDot(
              position: pos,
              isSelected: selected == pos,
              onTap: () => onChanged(pos),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _PositionDot extends StatelessWidget {
  final PageNumberPosition position;
  final bool isSelected;
  final VoidCallback onTap;

  const _PositionDot({
    required this.position,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.pageNumbersColor
              : Colors.grey.shade300,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.pageNumbersColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '#',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberPreview extends StatelessWidget {
  final PageNumberOptions options;

  const _NumberPreview({required this.options});

  @override
  Widget build(BuildContext context) {
    final preview = options.formatPageNumber(1, 10);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pageNumbersColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pageNumbersColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility, color: AppColors.pageNumbersColor),
          const SizedBox(width: 12),
          Text(
            'Preview: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Text(
            preview,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.pageNumbersColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _OptionsSection extends StatelessWidget {
  final PageNumberOptions options;
  final ValueChanged<PageNumberOptions> onChanged;

  const _OptionsSection({
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        'Advanced Options',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      children: [
        // Start number
        Row(
          children: [
            Expanded(
              child: Text(
                'Start from number',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: options.startNumber.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) {
                  final num = int.tryParse(value) ?? 1;
                  onChanged(options.copyWith(startNumber: num));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Font size
        Row(
          children: [
            Expanded(
              child: Text(
                'Font size',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: options.fontSize.toInt().toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  suffixText: 'pt',
                ),
                onChanged: (value) {
                  final size = double.tryParse(value) ?? 12;
                  onChanged(options.copyWith(fontSize: size));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Skip first page
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skip first page',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Don\'t add number to first page (cover)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: options.skipFirstPage,
              onChanged: (value) => onChanged(options.copyWith(skipFirstPage: value)),
              activeColor: AppColors.pageNumbersColor,
            ),
          ],
        ),

        // Prefix
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Prefix',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 100,
              child: TextFormField(
                initialValue: options.prefix,
                decoration: const InputDecoration(
                  hintText: 'e.g., "["',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) => onChanged(options.copyWith(prefix: value)),
              ),
            ),
          ],
        ),

        // Suffix
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Suffix',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 100,
              child: TextFormField(
                initialValue: options.suffix,
                decoration: const InputDecoration(
                  hintText: 'e.g., "]"',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) => onChanged(options.copyWith(suffix: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
