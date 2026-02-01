import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/extraction_options.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';

// Providers
final extractFileServiceProvider = Provider((ref) => FileService());
final extractPdfServiceProvider = Provider((ref) => PdfService());

final extractSelectedFileProvider = StateProvider<PdfFile?>((ref) => null);
final extractionOptionsProvider = StateProvider<ExtractionOptions>(
  (ref) => const ExtractionOptions(),
);
final pageCountProvider = StateProvider<int>((ref) => 0);
final extractStateProvider = StateProvider<ExtractState>(
  (ref) => const ExtractState.idle(),
);

// State classes
sealed class ExtractState {
  const ExtractState();
  const factory ExtractState.idle() = ExtractIdleState;
  const factory ExtractState.processing(double progress, String? step) =
      ExtractProcessingState;
  const factory ExtractState.success(ExtractionResult result) =
      ExtractSuccessState;
  const factory ExtractState.error(String message) = ExtractErrorState;
}

class ExtractIdleState extends ExtractState {
  const ExtractIdleState();
}

class ExtractProcessingState extends ExtractState {
  final double progress;
  final String? step;
  const ExtractProcessingState(this.progress, this.step);
}

class ExtractSuccessState extends ExtractState {
  final ExtractionResult result;
  const ExtractSuccessState(this.result);
}

class ExtractErrorState extends ExtractState {
  final String message;
  const ExtractErrorState(this.message);
}

class ExtractScreen extends ConsumerStatefulWidget {
  const ExtractScreen({super.key});

  @override
  ConsumerState<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends ConsumerState<ExtractScreen> {
  final _rangeController = TextEditingController();

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(extractSelectedFileProvider);
    final options = ref.watch(extractionOptionsProvider);
    final pageCount = ref.watch(pageCountProvider);
    final state = ref.watch(extractStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Pages'),
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
                fileSize: selectedFile != null
                    ? '${selectedFile.formattedSize} • $pageCount pages'
                    : null,
                onClear: selectedFile != null
                    ? () {
                        ref.read(extractSelectedFileProvider.notifier).state =
                            null;
                        ref.read(pageCountProvider.notifier).state = 0;
                      }
                    : null,
                isLoading: state is ExtractProcessingState,
              ),

              if (selectedFile != null &&
                  pageCount > 0 &&
                  state is! ExtractProcessingState) ...[
                const SizedBox(height: 32),

                // Extraction mode selection
                Text(
                  'Extraction Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _ExtractionModeSelector(
                  selected: options.mode,
                  onChanged: (mode) {
                    ref.read(extractionOptionsProvider.notifier).state =
                        options.copyWith(mode: mode, selectedPages: []);
                  },
                ),

                const SizedBox(height: 24),

                // Mode-specific controls
                if (options.mode == ExtractionMode.selectPages) ...[
                  _PageSelector(
                    totalPages: pageCount,
                    selectedPages: options.selectedPages,
                    onChanged: (pages) {
                      ref.read(extractionOptionsProvider.notifier).state =
                          options.copyWith(selectedPages: pages);
                    },
                  ),
                ],

                if (options.mode == ExtractionMode.pageRange) ...[
                  _PageRangeInput(
                    controller: _rangeController,
                    totalPages: pageCount,
                    onChanged: (range) {
                      ref.read(extractionOptionsProvider.notifier).state =
                          options.copyWith(pageRange: range);
                    },
                  ),
                ],

                if (options.mode == ExtractionMode.oddPages ||
                    options.mode == ExtractionMode.evenPages) ...[
                  _PreviewPages(
                    mode: options.mode,
                    totalPages: pageCount,
                  ),
                ],

                const SizedBox(height: 32),

                // Extract button
                ElevatedButton.icon(
                  onPressed: _canExtract(options, pageCount)
                      ? () => _extract(context, ref)
                      : null,
                  icon: const Icon(Icons.content_cut),
                  label: Text(_getButtonText(options, pageCount)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.extractColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is ExtractProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Extracting Pages',
                ),
              ],

              // Success state
              if (state is ExtractSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Extraction Complete!',
                  subtitle: 'Your pages have been extracted successfully',
                  stats: [
                    ResultStat(
                      label: 'Pages Extracted',
                      value: '${state.result.extractedPages}',
                    ),
                    ResultStat(
                      label: 'Output Size',
                      value: state.result.formattedSize,
                    ),
                  ],
                  onTertiaryAction: () =>
                      _saveResult(context, state.result.outputPath),
                  tertiaryActionText: 'Save',
                  onPrimaryAction: () =>
                      _shareResult(ref, state.result.outputPath),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Extract More',
                ),
              ],

              // Error state
              if (state is ExtractErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Extraction Failed',
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

  bool _canExtract(ExtractionOptions options, int totalPages) {
    switch (options.mode) {
      case ExtractionMode.selectPages:
        return options.selectedPages.isNotEmpty;
      case ExtractionMode.pageRange:
        return options.pageRange != null;
      case ExtractionMode.oddPages:
      case ExtractionMode.evenPages:
        return totalPages > 0;
    }
  }

  String _getButtonText(ExtractionOptions options, int totalPages) {
    final pages = options.getEffectivePages(totalPages);
    if (pages.isEmpty) return 'Select Pages';
    return 'Extract ${pages.length} Page${pages.length == 1 ? '' : 's'}';
  }

  Future<void> _selectFile(WidgetRef ref) async {
    final fileService = ref.read(extractFileServiceProvider);
    final pdfService = ref.read(extractPdfServiceProvider);

    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(extractSelectedFileProvider.notifier).state = files.first;
      ref.read(extractStateProvider.notifier).state = const ExtractState.idle();

      // Get page count
      final metadata = await pdfService.getPdfMetadata(files.first.filePath);
      if (metadata != null) {
        ref.read(pageCountProvider.notifier).state = metadata.pageCount;
      }
    }
  }

  Future<void> _extract(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(extractSelectedFileProvider);
    final options = ref.read(extractionOptionsProvider);
    final pageCount = ref.read(pageCountProvider);
    final fileService = ref.read(extractFileServiceProvider);
    final pdfService = ref.read(extractPdfServiceProvider);

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_extracted',
    );

    final result = await pdfService.extractPages(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      options: options,
      totalPages: pageCount,
      onProgress: (progress, step) {
        ref.read(extractStateProvider.notifier).state =
            ExtractState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<ExtractionResult>) {
      ref.read(extractStateProvider.notifier).state =
          ExtractState.success(result.data);
    } else if (result is OperationFailure<ExtractionResult>) {
      ref.read(extractStateProvider.notifier).state =
          ExtractState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, String outputPath) async {
    final fileService = ref.read(extractFileServiceProvider);
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
    ref.read(extractSelectedFileProvider.notifier).state = null;
    ref.read(pageCountProvider.notifier).state = 0;
    ref.read(extractionOptionsProvider.notifier).state =
        const ExtractionOptions();
    ref.read(extractStateProvider.notifier).state = const ExtractState.idle();
    _rangeController.clear();
  }
}

class _ExtractionModeSelector extends StatelessWidget {
  final ExtractionMode selected;
  final ValueChanged<ExtractionMode> onChanged;

  const _ExtractionModeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ExtractionMode.values.map((mode) {
        final isSelected = mode == selected;
        return GestureDetector(
          onTap: () => onChanged(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.extractColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.extractColor
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mode.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      mode.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppColors.extractColor : null,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PageSelector extends StatelessWidget {
  final int totalPages;
  final List<int> selectedPages;
  final ValueChanged<List<int>> onChanged;

  const _PageSelector({
    required this.totalPages,
    required this.selectedPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Pages',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            TextButton(
              onPressed: () {
                if (selectedPages.length == totalPages) {
                  onChanged([]);
                } else {
                  onChanged(List.generate(totalPages, (i) => i));
                }
              },
              child: Text(
                selectedPages.length == totalPages ? 'Deselect All' : 'Select All',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(totalPages, (index) {
                final isSelected = selectedPages.contains(index);
                return GestureDetector(
                  onTap: () {
                    final newList = [...selectedPages];
                    if (isSelected) {
                      newList.remove(index);
                    } else {
                      newList.add(index);
                      newList.sort();
                    }
                    onChanged(newList);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.extractColor
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.extractColor
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${selectedPages.length} of $totalPages pages selected',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _PageRangeInput extends StatelessWidget {
  final TextEditingController controller;
  final int totalPages;
  final ValueChanged<PageRange?> onChanged;

  const _PageRangeInput({
    required this.controller,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Page Range',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g., 1-5',
            helperText: 'Enter range from 1 to $totalPages',
          ),
          keyboardType: TextInputType.text,
          onChanged: (value) {
            final range = PageRange.parse(value);
            onChanged(range);
          },
        ),
      ],
    );
  }
}

class _PreviewPages extends StatelessWidget {
  final ExtractionMode mode;
  final int totalPages;

  const _PreviewPages({
    required this.mode,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final pages = mode == ExtractionMode.oddPages
        ? List.generate(totalPages, (i) => i).where((p) => p % 2 == 0).toList()
        : List.generate(totalPages, (i) => i).where((p) => p % 2 == 1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pages to Extract',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.extractColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.extractColor.withOpacity(0.2)),
          ),
          child: Text(
            pages.isEmpty
                ? 'No pages match this criteria'
                : 'Pages: ${pages.map((p) => p + 1).join(", ")}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${pages.length} pages will be extracted',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
