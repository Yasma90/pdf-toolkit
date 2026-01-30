import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/compression_level.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';

// Providers
final fileServiceProvider = Provider((ref) => FileService());
final pdfServiceProvider = Provider((ref) => PdfService());

final selectedFileProvider = StateProvider<PdfFile?>((ref) => null);
final compressionOptionsProvider = StateProvider<CompressionOptions>(
  (ref) => const CompressionOptions(),
);
final compressionStateProvider = StateProvider<CompressionState>(
  (ref) => const CompressionState.idle(),
);

// State classes
sealed class CompressionState {
  const CompressionState();
  const factory CompressionState.idle() = IdleState;
  const factory CompressionState.processing(double progress, String? step) =
      ProcessingState;
  const factory CompressionState.success(CompressionResult result) =
      SuccessState;
  const factory CompressionState.error(String message) = ErrorState;
}

class IdleState extends CompressionState {
  const IdleState();
}

class ProcessingState extends CompressionState {
  final double progress;
  final String? step;
  const ProcessingState(this.progress, this.step);
}

class SuccessState extends CompressionState {
  final CompressionResult result;
  const SuccessState(this.result);
}

class ErrorState extends CompressionState {
  final String message;
  const ErrorState(this.message);
}

class CompressScreen extends ConsumerWidget {
  const CompressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(selectedFileProvider);
    final options = ref.watch(compressionOptionsProvider);
    final state = ref.watch(compressionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF'),
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
                    ? () => ref.read(selectedFileProvider.notifier).state = null
                    : null,
                isLoading: state is ProcessingState,
              ),

              if (selectedFile != null && state is! ProcessingState) ...[
                const SizedBox(height: 32),

                // Compression level selection
                Text(
                  'Compression Level',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _CompressionLevelSelector(
                  selected: options.level,
                  onChanged: (level) {
                    ref.read(compressionOptionsProvider.notifier).state =
                        options.copyWith(level: level);
                  },
                ),

                // Advanced options
                const SizedBox(height: 24),
                _AdvancedOptions(
                  options: options,
                  onChanged: (newOptions) {
                    ref.read(compressionOptionsProvider.notifier).state =
                        newOptions;
                  },
                ),

                const SizedBox(height: 32),

                // Compress button
                ElevatedButton.icon(
                  onPressed: () => _compress(context, ref),
                  icon: const Icon(Icons.compress),
                  label: const Text('Compress PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.compressColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is ProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Compressing PDF',
                ),
              ],

              // Success state
              if (state is SuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Compression Complete!',
                  subtitle: 'Your PDF has been compressed successfully',
                  stats: [
                    ResultStat(
                      label: 'Original Size',
                      value: state.result.formattedOriginalSize,
                    ),
                    ResultStat(
                      label: 'Compressed Size',
                      value: state.result.formattedCompressedSize,
                    ),
                    ResultStat(
                      label: 'Size Reduction',
                      value: state.result.formattedReduction,
                      valueColor: AppColors.success,
                    ),
                  ],
                  onPrimaryAction: () => _shareResult(ref, state.result),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Compress Another',
                ),
              ],

              // Error state
              if (state is ErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Compression Failed',
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
    final fileService = ref.read(fileServiceProvider);
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(selectedFileProvider.notifier).state = files.first;
      ref.read(compressionStateProvider.notifier).state =
          const CompressionState.idle();
    }
  }

  Future<void> _compress(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(selectedFileProvider);
    final options = ref.read(compressionOptionsProvider);
    final fileService = ref.read(fileServiceProvider);
    final pdfService = ref.read(pdfServiceProvider);

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_compressed',
    );

    final result = await pdfService.compressPdf(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      options: options,
      onProgress: (progress, step) {
        ref.read(compressionStateProvider.notifier).state =
            CompressionState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<CompressionResult>) {
      ref.read(compressionStateProvider.notifier).state =
          CompressionState.success(result.data);
    } else if (result is OperationFailure<CompressionResult>) {
      ref.read(compressionStateProvider.notifier).state =
          CompressionState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, CompressionResult result) async {
    final fileService = ref.read(fileServiceProvider);
    await fileService.shareFile(result.outputPath);
  }

  void _reset(WidgetRef ref) {
    ref.read(selectedFileProvider.notifier).state = null;
    ref.read(compressionStateProvider.notifier).state =
        const CompressionState.idle();
  }
}

class _CompressionLevelSelector extends StatelessWidget {
  final CompressionLevel selected;
  final ValueChanged<CompressionLevel> onChanged;

  const _CompressionLevelSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final levels = CompressionLevel.values
        .where((l) => l != CompressionLevel.custom)
        .toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: levels.map((level) {
        final isSelected = level == selected;
        return GestureDetector(
          onTap: () => onChanged(level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.compressColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.compressColor
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
                    Text(level.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      level.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.compressColor
                                : null,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  level.expectedReduction,
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

class _AdvancedOptions extends StatelessWidget {
  final CompressionOptions options;
  final ValueChanged<CompressionOptions> onChanged;

  const _AdvancedOptions({
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
        _OptionSwitch(
          title: 'Compress Images',
          subtitle: 'Reduce image quality to decrease file size',
          value: options.compressImages,
          onChanged: (value) =>
              onChanged(options.copyWith(compressImages: value)),
        ),
        _OptionSwitch(
          title: 'Remove Metadata',
          subtitle: 'Strip author, title, and other document info',
          value: options.removeMetadata,
          onChanged: (value) =>
              onChanged(options.copyWith(removeMetadata: value)),
        ),
        _OptionSwitch(
          title: 'Remove Annotations',
          subtitle: 'Remove comments and markup from the PDF',
          value: options.removeAnnotations,
          onChanged: (value) =>
              onChanged(options.copyWith(removeAnnotations: value)),
        ),
        _OptionSwitch(
          title: 'Optimize for Web',
          subtitle: 'Linearize PDF for faster web loading',
          value: options.linearize,
          onChanged: (value) => onChanged(options.copyWith(linearize: value)),
        ),
      ],
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.compressColor,
          ),
        ],
      ),
    );
  }
}
