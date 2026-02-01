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
final rotateFileProvider = StateProvider<PdfFile?>((ref) => null);
final rotateOptionsProvider = StateProvider<RotateOptions>(
  (ref) => const RotateOptions(),
);
final rotateStateProvider = StateProvider<RotateState>(
  (ref) => const RotateState.idle(),
);

// State classes
sealed class RotateState {
  const RotateState();
  const factory RotateState.idle() = RotateIdleState;
  const factory RotateState.processing(double progress, String? step) =
      RotateProcessingState;
  const factory RotateState.success(String outputPath) = RotateSuccessState;
  const factory RotateState.error(String message) = RotateErrorState;
}

class RotateIdleState extends RotateState {
  const RotateIdleState();
}

class RotateProcessingState extends RotateState {
  final double progress;
  final String? step;
  const RotateProcessingState(this.progress, this.step);
}

class RotateSuccessState extends RotateState {
  final String outputPath;
  const RotateSuccessState(this.outputPath);
}

class RotateErrorState extends RotateState {
  final String message;
  const RotateErrorState(this.message);
}

class RotateScreen extends ConsumerWidget {
  const RotateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(rotateFileProvider);
    final options = ref.watch(rotateOptionsProvider);
    final state = ref.watch(rotateStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate Pages'),
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
                    ? () => ref.read(rotateFileProvider.notifier).state = null
                    : null,
                isLoading: state is RotateProcessingState,
              ),

              if (selectedFile != null && state is! RotateProcessingState) ...[
                const SizedBox(height: 32),

                // Rotation angle selection
                Text(
                  'Rotation Angle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _RotationSelector(
                  selected: options.angle,
                  onChanged: (angle) {
                    ref.read(rotateOptionsProvider.notifier).state =
                        options.copyWith(angle: angle);
                  },
                ),

                const SizedBox(height: 24),

                // Page selection
                Text(
                  'Pages to Rotate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _PageSelectionToggle(
                  allPages: options.allPages,
                  onChanged: (allPages) {
                    ref.read(rotateOptionsProvider.notifier).state =
                        options.copyWith(allPages: allPages);
                  },
                ),

                if (!options.allPages) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'Enter page numbers (e.g., 1, 3, 5-10)',
                      prefixIcon: Icon(Icons.format_list_numbered),
                      helperText: 'Separate pages with commas, use dash for ranges',
                    ),
                    onChanged: (value) {
                      final pages = _parsePageNumbers(value);
                      ref.read(rotateOptionsProvider.notifier).state =
                          options.copyWith(specificPages: pages);
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // Rotate button
                ElevatedButton.icon(
                  onPressed: () => _rotate(context, ref),
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Rotate PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rotateColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is RotateProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Rotating Pages',
                ),
              ],

              // Success state
              if (state is RotateSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Rotation Complete!',
                  subtitle: 'Your PDF pages have been rotated successfully',
                  onTertiaryAction: () => _saveResult(context, state.outputPath),
                  tertiaryActionText: 'Save',
                  onPrimaryAction: () => _shareResult(ref, state.outputPath),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Rotate Another',
                ),
              ],

              // Error state
              if (state is RotateErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Rotation Failed',
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

  List<int> _parsePageNumbers(String input) {
    final pages = <int>[];
    final parts = input.split(',');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              pages.add(i - 1); // Convert to 0-indexed
            }
          }
        }
      } else {
        final page = int.tryParse(trimmed);
        if (page != null && page > 0) {
          pages.add(page - 1); // Convert to 0-indexed
        }
      }
    }

    return pages.toSet().toList()..sort();
  }

  Future<void> _selectFile(WidgetRef ref) async {
    final fileService = FileService();
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(rotateFileProvider.notifier).state = files.first;
      ref.read(rotateStateProvider.notifier).state = const RotateState.idle();
    }
  }

  Future<void> _rotate(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(rotateFileProvider);
    final options = ref.read(rotateOptionsProvider);
    final fileService = FileService();
    final processor = PdfProcessor();

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_rotated',
    );

    final result = await processor.rotatePages(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      options: options,
      onProgress: (progress, step) {
        ref.read(rotateStateProvider.notifier).state =
            RotateState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<String>) {
      ref.read(rotateStateProvider.notifier).state =
          RotateState.success(result.data);

      // Add to recent files
      ref.read(recentFilesProvider.notifier).addEntry(
        filePath: result.data,
        operation: 'Rotate',
      );
    } else if (result is OperationFailure<String>) {
      ref.read(rotateStateProvider.notifier).state =
          RotateState.error(result.error);
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
    ref.read(rotateFileProvider.notifier).state = null;
    ref.read(rotateStateProvider.notifier).state = const RotateState.idle();
  }
}

class _RotationSelector extends StatelessWidget {
  final RotationAngle selected;
  final ValueChanged<RotationAngle> onChanged;

  const _RotationSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RotationAngle.values.map((angle) {
        final isSelected = angle == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(angle),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.rotateColor.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.rotateColor
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  _RotationIcon(angle: angle, isSelected: isSelected),
                  const SizedBox(height: 8),
                  Text(
                    angle.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppColors.rotateColor : null,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RotationIcon extends StatelessWidget {
  final RotationAngle angle;
  final bool isSelected;

  const _RotationIcon({
    required this.angle,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (angle) {
      case RotationAngle.clockwise90:
        icon = Icons.rotate_right;
        break;
      case RotationAngle.clockwise180:
        icon = Icons.sync;
        break;
      case RotationAngle.clockwise270:
        icon = Icons.rotate_left;
        break;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.rotateColor.withOpacity(0.2)
            : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 28,
        color: isSelected ? AppColors.rotateColor : Colors.grey.shade600,
      ),
    );
  }
}

class _PageSelectionToggle extends StatelessWidget {
  final bool allPages;
  final ValueChanged<bool> onChanged;

  const _PageSelectionToggle({
    required this.allPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'All Pages',
            icon: Icons.select_all,
            isSelected: allPages,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleButton(
            label: 'Specific Pages',
            icon: Icons.filter_list,
            isSelected: !allPages,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.rotateColor.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.rotateColor
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.rotateColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.rotateColor : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
