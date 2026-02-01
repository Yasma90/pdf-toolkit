import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/compression_level.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/ghostscript_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';
import 'package:url_launcher/url_launcher.dart';

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

// Provider to check if Ghostscript is available (Windows only)
final ghostscriptAvailableProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isWindows) return true; // Not needed on Android
  return await GhostscriptService.isAvailable();
});

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

  // Check if compression is available on this platform
  // Windows uses Ghostscript, Android uses iText-based pdf_compressor
  bool get _isCompressionAvailable => Platform.isWindows || Platform.isAndroid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(selectedFileProvider);
    final options = ref.watch(compressionOptionsProvider);
    final state = ref.watch(compressionStateProvider);
    final ghostscriptAvailable = ref.watch(ghostscriptAvailableProvider);

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
              // Platform not supported message
              if (!_isCompressionAvailable) ...[
                _PlatformNotSupportedCard(),
                const SizedBox(height: 24),
              ],

              // Ghostscript not installed warning (Windows only)
              if (Platform.isWindows && ghostscriptAvailable.value == false) ...[
                const _GhostscriptNotInstalledCard(),
                const SizedBox(height: 24),
              ],

              // File selection (disabled on unsupported platforms)
              IgnorePointer(
                ignoring: !_isCompressionAvailable,
                child: Opacity(
                  opacity: _isCompressionAvailable ? 1.0 : 0.5,
                  child: FileDropZone(
                    onTap: () => _selectFile(ref),
                    onFilesDropped: (paths) => _handleDroppedFiles(ref, paths),
                    selectedFileName: selectedFile?.fileName,
                    fileSize: selectedFile?.formattedSize,
                    onClear: selectedFile != null
                        ? () => ref.read(selectedFileProvider.notifier).state = null
                        : null,
                    isLoading: state is ProcessingState,
                  ),
                ),
              ),

              if (selectedFile != null && state is! ProcessingState && _isCompressionAvailable) ...[
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
                  onTertiaryAction: () => _saveResult(context, ref, state.result),
                  tertiaryActionText: 'Save',
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

  Future<void> _handleDroppedFiles(WidgetRef ref, List<String> paths) async {
    if (paths.isEmpty) return;
    final file = File(paths.first);
    if (await file.exists()) {
      final pdfFile = await PdfFile.fromFile(file);
      ref.read(selectedFileProvider.notifier).state = pdfFile;
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

  Future<void> _saveResult(BuildContext context, WidgetRef ref, CompressionResult result) async {
    final fileService = ref.read(fileServiceProvider);
    final savedPath = await fileService.saveFileAs(result.outputPath);

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

class _PlatformNotSupportedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Not Available on This Platform',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF compression requires Ghostscript which is only available on Windows.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.computer,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use the Windows version of this app for full PDF compression with up to 90% file size reduction.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostscriptNotInstalledCard extends StatelessWidget {
  const _GhostscriptNotInstalledCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Install Ghostscript for Best Compression',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ghostscript enables professional-grade compression with 30-90% file size reduction.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://ghostscript.com/releases/gsdnld.html');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Ghostscript (Free)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'After installing, restart the app. Choose the 64-bit AGPL version.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
