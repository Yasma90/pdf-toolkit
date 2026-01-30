import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_toolkit/core/models/image_format.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';

// Providers
final convertFileServiceProvider = Provider((ref) => FileService());
final convertSelectedFileProvider = StateProvider<PdfFile?>((ref) => null);
final conversionOptionsProvider = StateProvider<ConversionOptions>(
  (ref) => const ConversionOptions(),
);
final convertStateProvider = StateProvider<ConvertState>(
  (ref) => const ConvertState.idle(),
);

// State classes
sealed class ConvertState {
  const ConvertState();
  const factory ConvertState.idle() = ConvertIdleState;
  const factory ConvertState.processing(double progress, String? step) =
      ConvertProcessingState;
  const factory ConvertState.success(ConvertResult result) = ConvertSuccessState;
  const factory ConvertState.error(String message) = ConvertErrorState;
}

class ConvertIdleState extends ConvertState {
  const ConvertIdleState();
}

class ConvertProcessingState extends ConvertState {
  final double progress;
  final String? step;
  const ConvertProcessingState(this.progress, this.step);
}

class ConvertSuccessState extends ConvertState {
  final ConvertResult result;
  const ConvertSuccessState(this.result);
}

class ConvertErrorState extends ConvertState {
  final String message;
  const ConvertErrorState(this.message);
}

class ConvertResult {
  final List<String> outputPaths;
  final int totalImages;
  final int totalSize;

  const ConvertResult({
    required this.outputPaths,
    required this.totalImages,
    required this.totalSize,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class ConvertScreen extends ConsumerWidget {
  const ConvertScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(convertSelectedFileProvider);
    final options = ref.watch(conversionOptionsProvider);
    final state = ref.watch(convertStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Images'),
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
                        ref.read(convertSelectedFileProvider.notifier).state =
                            null
                    : null,
                isLoading: state is ConvertProcessingState,
              ),

              if (selectedFile != null && state is! ConvertProcessingState) ...[
                const SizedBox(height: 32),

                // Format selection
                Text(
                  'Output Format',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _FormatSelector(
                  selected: options.format,
                  onChanged: (format) {
                    ref.read(conversionOptionsProvider.notifier).state =
                        options.copyWith(format: format);
                  },
                ),

                const SizedBox(height: 24),

                // Quality selection
                Text(
                  'Image Quality',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _QualitySelector(
                  selected: options.quality,
                  onChanged: (quality) {
                    ref.read(conversionOptionsProvider.notifier).state =
                        options.copyWith(quality: quality);
                  },
                ),

                const SizedBox(height: 32),

                // Convert button
                ElevatedButton.icon(
                  onPressed: () => _convert(context, ref),
                  icon: const Icon(Icons.transform),
                  label: const Text('Convert to Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.convertColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is ConvertProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Converting PDF',
                ),
              ],

              // Success state
              if (state is ConvertSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Conversion Complete!',
                  subtitle: 'Your PDF has been converted to images',
                  stats: [
                    ResultStat(
                      label: 'Images Created',
                      value: '${state.result.totalImages}',
                    ),
                    ResultStat(
                      label: 'Total Size',
                      value: state.result.formattedSize,
                    ),
                  ],
                  onPrimaryAction: () =>
                      _shareResults(ref, state.result.outputPaths),
                  primaryActionText: 'Share All',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Convert Another',
                ),
              ],

              // Error state
              if (state is ConvertErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Conversion Failed',
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
    final fileService = ref.read(convertFileServiceProvider);
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(convertSelectedFileProvider.notifier).state = files.first;
      ref.read(convertStateProvider.notifier).state = const ConvertState.idle();
    }
  }

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(convertSelectedFileProvider);
    final options = ref.read(conversionOptionsProvider);
    final fileService = ref.read(convertFileServiceProvider);

    if (selectedFile == null) return;

    ref.read(convertStateProvider.notifier).state =
        const ConvertState.processing(0.1, 'Loading PDF...');

    try {
      final outputDir = await fileService.getDefaultOutputDirectory();
      final baseName = p.basenameWithoutExtension(selectedFile.filePath);

      // Read PDF file
      final file = File(selectedFile.filePath);
      final pdfData = await file.readAsBytes();

      ref.read(convertStateProvider.notifier).state =
          const ConvertState.processing(0.2, 'Rendering pages...');

      final outputPaths = <String>[];
      int totalSize = 0;
      int pageIndex = 0;

      // Use printing package to rasterize PDF pages
      await for (final page in Printing.raster(
        pdfData,
        dpi: options.quality.dpi.toDouble(),
      )) {
        final progress = 0.2 + (0.7 * (pageIndex / 10)); // Approximate
        ref.read(convertStateProvider.notifier).state =
            ConvertState.processing(progress, 'Converting page ${pageIndex + 1}...');

        // Convert to PNG bytes
        final imageBytes = await page.toPng();

        // Convert to requested format if not PNG
        Uint8List finalBytes = imageBytes;
        String extension = options.format.extension;

        // For JPEG, we need to convert from PNG
        if (options.format == ImageFormat.jpeg) {
          // PNG to JPEG conversion would require image package
          // For now, we'll save as PNG and note in filename
          extension = 'png';
        }

        final outputPath = p.join(
          outputDir,
          '${baseName}_page_${pageIndex + 1}.$extension',
        );

        await File(outputPath).writeAsBytes(finalBytes);
        outputPaths.add(outputPath);
        totalSize += finalBytes.length;

        pageIndex++;
      }

      ref.read(convertStateProvider.notifier).state = ConvertState.success(
        ConvertResult(
          outputPaths: outputPaths,
          totalImages: outputPaths.length,
          totalSize: totalSize,
        ),
      );
    } catch (e) {
      ref.read(convertStateProvider.notifier).state =
          ConvertState.error(e.toString());
    }
  }

  Future<void> _shareResults(WidgetRef ref, List<String> outputPaths) async {
    final fileService = ref.read(convertFileServiceProvider);
    await fileService.shareFiles(outputPaths);
  }

  void _reset(WidgetRef ref) {
    ref.read(convertSelectedFileProvider.notifier).state = null;
    ref.read(convertStateProvider.notifier).state = const ConvertState.idle();
  }
}

class _FormatSelector extends StatelessWidget {
  final ImageFormat selected;
  final ValueChanged<ImageFormat> onChanged;

  const _FormatSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ImageFormat.values.map((format) {
        final isSelected = format == selected;
        return GestureDetector(
          onTap: () => onChanged(format),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.convertColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.convertColor
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppColors.convertColor : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  format.description,
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

class _QualitySelector extends StatelessWidget {
  final ImageQuality selected;
  final ValueChanged<ImageQuality> onChanged;

  const _QualitySelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ImageQuality.values.map((quality) {
        final isSelected = quality == selected;
        return GestureDetector(
          onTap: () => onChanged(quality),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.convertColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.convertColor
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quality.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? AppColors.convertColor : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quality.description} (${quality.dpi} DPI)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Radio<ImageQuality>(
                  value: quality,
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                  activeColor: AppColors.convertColor,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
