import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';

// Providers
final splitFileServiceProvider = Provider((ref) => FileService());
final splitPdfServiceProvider = Provider((ref) => PdfService());

final splitSelectedFileProvider = StateProvider<PdfFile?>((ref) => null);
final splitModeProvider = StateProvider<SplitMode>((ref) => SplitMode.everyPage);
final pagesPerFileProvider = StateProvider<int>((ref) => 1);
final splitStateProvider = StateProvider<SplitState>(
  (ref) => const SplitState.idle(),
);

// State classes
sealed class SplitState {
  const SplitState();
  const factory SplitState.idle() = SplitIdleState;
  const factory SplitState.processing(double progress, String? step) =
      SplitProcessingState;
  const factory SplitState.success(SplitResult result) = SplitSuccessState;
  const factory SplitState.error(String message) = SplitErrorState;
}

class SplitIdleState extends SplitState {
  const SplitIdleState();
}

class SplitProcessingState extends SplitState {
  final double progress;
  final String? step;
  const SplitProcessingState(this.progress, this.step);
}

class SplitSuccessState extends SplitState {
  final SplitResult result;
  const SplitSuccessState(this.result);
}

class SplitErrorState extends SplitState {
  final String message;
  const SplitErrorState(this.message);
}

class SplitScreen extends ConsumerWidget {
  const SplitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(splitSelectedFileProvider);
    final splitMode = ref.watch(splitModeProvider);
    final pagesPerFile = ref.watch(pagesPerFileProvider);
    final state = ref.watch(splitStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
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
                    ? () =>
                        ref.read(splitSelectedFileProvider.notifier).state = null
                    : null,
                isLoading: state is SplitProcessingState,
              ),

              if (selectedFile != null && state is! SplitProcessingState) ...[
                const SizedBox(height: 32),

                // Split mode selection
                Text(
                  'Split Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _SplitModeSelector(
                  selected: splitMode,
                  onChanged: (mode) {
                    ref.read(splitModeProvider.notifier).state = mode;
                  },
                ),

                // Pages per file (only for byPageCount mode)
                if (splitMode == SplitMode.byPageCount) ...[
                  const SizedBox(height: 24),
                  _PagesPerFileSelector(
                    value: pagesPerFile,
                    onChanged: (value) {
                      ref.read(pagesPerFileProvider.notifier).state = value;
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // Split button
                ElevatedButton.icon(
                  onPressed: () => _split(context, ref),
                  icon: const Icon(Icons.call_split),
                  label: const Text('Split PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.splitColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is SplitProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Splitting PDF',
                ),
              ],

              // Success state
              if (state is SplitSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Split Complete!',
                  subtitle: 'Your PDF has been split successfully',
                  stats: [
                    ResultStat(
                      label: 'Files Created',
                      value: '${state.result.totalFiles}',
                    ),
                    ResultStat(
                      label: 'Total Size',
                      value: _formatSize(state.result.totalSize),
                    ),
                  ],
                  onTertiaryAction: () =>
                      _saveResults(context, ref, state.result.outputPaths),
                  tertiaryActionText: 'Save All',
                  onPrimaryAction: () =>
                      _shareResults(ref, state.result.outputPaths),
                  primaryActionText: 'Share All',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Split Another',
                ),
              ],

              // Error state
              if (state is SplitErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Split Failed',
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
    final fileService = ref.read(splitFileServiceProvider);
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(splitSelectedFileProvider.notifier).state = files.first;
      ref.read(splitStateProvider.notifier).state = const SplitState.idle();
    }
  }

  Future<void> _split(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(splitSelectedFileProvider);
    final splitMode = ref.read(splitModeProvider);
    final pagesPerFile = ref.read(pagesPerFileProvider);
    final fileService = ref.read(splitFileServiceProvider);
    final pdfService = ref.read(splitPdfServiceProvider);

    if (selectedFile == null) return;

    final outputDir = await fileService.getDefaultOutputDirectory();

    final result = await pdfService.splitPdf(
      inputPath: selectedFile.filePath,
      outputDirectory: outputDir,
      mode: splitMode,
      pagesPerFile: pagesPerFile,
      onProgress: (progress, step) {
        ref.read(splitStateProvider.notifier).state =
            SplitState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<SplitResult>) {
      ref.read(splitStateProvider.notifier).state =
          SplitState.success(result.data);
    } else if (result is OperationFailure<SplitResult>) {
      ref.read(splitStateProvider.notifier).state =
          SplitState.error(result.error);
    }
  }

  Future<void> _shareResults(WidgetRef ref, List<String> outputPaths) async {
    final fileService = ref.read(splitFileServiceProvider);
    await fileService.shareFiles(outputPaths);
  }

  Future<void> _saveResults(BuildContext context, WidgetRef ref, List<String> outputPaths) async {
    final fileService = ref.read(splitFileServiceProvider);
    final savedDir = await fileService.pickOutputDirectory();

    if (savedDir != null) {
      int savedCount = 0;
      for (final path in outputPaths) {
        final fileName = path.split(RegExp(r'[/\\]')).last;
        final destPath = '$savedDir${Platform.pathSeparator}$fileName';
        final result = await fileService.copyFile(path, destPath);
        if (result != null) savedCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $savedCount files to: $savedDir'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _reset(WidgetRef ref) {
    ref.read(splitSelectedFileProvider.notifier).state = null;
    ref.read(splitStateProvider.notifier).state = const SplitState.idle();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _SplitModeSelector extends StatelessWidget {
  final SplitMode selected;
  final ValueChanged<SplitMode> onChanged;

  const _SplitModeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modes = [
      (
        mode: SplitMode.everyPage,
        icon: Icons.view_day,
        title: 'Every Page',
        description: 'Create one PDF per page',
      ),
      (
        mode: SplitMode.byPageCount,
        icon: Icons.view_module,
        title: 'By Page Count',
        description: 'Specify pages per file',
      ),
    ];

    return Column(
      children: modes.map((item) {
        final isSelected = item.mode == selected;
        return GestureDetector(
          onTap: () => onChanged(item.mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.splitColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.splitColor
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.splitColor.withOpacity(0.2)
                        : AppColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    color:
                        isSelected ? AppColors.splitColor : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.splitColor
                                      : null,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
                Radio<SplitMode>(
                  value: item.mode,
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                  activeColor: AppColors.splitColor,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PagesPerFileSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PagesPerFileSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pages per file',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.splitColor.withOpacity(0.1),
                  foregroundColor: AppColors.splitColor,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.splitColor,
                        ),
                  ),
                  Text(
                    value == 1 ? 'page' : 'pages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.splitColor.withOpacity(0.1),
                  foregroundColor: AppColors.splitColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
