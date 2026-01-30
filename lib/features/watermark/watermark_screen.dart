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
final watermarkFileProvider = StateProvider<PdfFile?>((ref) => null);
final watermarkOptionsProvider = StateProvider<WatermarkOptions>(
  (ref) => const WatermarkOptions(),
);
final watermarkStateProvider = StateProvider<WatermarkState>(
  (ref) => const WatermarkState.idle(),
);

// State classes
sealed class WatermarkState {
  const WatermarkState();
  const factory WatermarkState.idle() = WatermarkIdleState;
  const factory WatermarkState.processing(double progress, String? step) =
      WatermarkProcessingState;
  const factory WatermarkState.success(String outputPath) =
      WatermarkSuccessState;
  const factory WatermarkState.error(String message) = WatermarkErrorState;
}

class WatermarkIdleState extends WatermarkState {
  const WatermarkIdleState();
}

class WatermarkProcessingState extends WatermarkState {
  final double progress;
  final String? step;
  const WatermarkProcessingState(this.progress, this.step);
}

class WatermarkSuccessState extends WatermarkState {
  final String outputPath;
  const WatermarkSuccessState(this.outputPath);
}

class WatermarkErrorState extends WatermarkState {
  final String message;
  const WatermarkErrorState(this.message);
}

class WatermarkScreen extends ConsumerWidget {
  const WatermarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(watermarkFileProvider);
    final options = ref.watch(watermarkOptionsProvider);
    final state = ref.watch(watermarkStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Watermark'),
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
                    ? () => ref.read(watermarkFileProvider.notifier).state = null
                    : null,
                isLoading: state is WatermarkProcessingState,
              ),

              if (selectedFile != null && state is! WatermarkProcessingState) ...[
                const SizedBox(height: 32),

                // Watermark text
                Text(
                  'Watermark Text',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: options.text,
                  decoration: const InputDecoration(
                    hintText: 'Enter watermark text',
                    prefixIcon: Icon(Icons.text_fields),
                  ),
                  onChanged: (value) {
                    ref.read(watermarkOptionsProvider.notifier).state =
                        options.copyWith(text: value);
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
                _PositionGrid(
                  selected: options.position,
                  onChanged: (position) {
                    ref.read(watermarkOptionsProvider.notifier).state =
                        options.copyWith(position: position);
                  },
                ),

                const SizedBox(height: 24),

                // Opacity slider
                _SliderOption(
                  title: 'Opacity',
                  value: options.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  valueLabel: '${(options.opacity * 100).toInt()}%',
                  onChanged: (value) {
                    ref.read(watermarkOptionsProvider.notifier).state =
                        options.copyWith(opacity: value);
                  },
                ),

                // Font size slider
                _SliderOption(
                  title: 'Font Size',
                  value: options.fontSize,
                  min: 12,
                  max: 120,
                  divisions: 27,
                  valueLabel: '${options.fontSize.toInt()}pt',
                  onChanged: (value) {
                    ref.read(watermarkOptionsProvider.notifier).state =
                        options.copyWith(fontSize: value);
                  },
                ),

                // Rotation slider
                _SliderOption(
                  title: 'Rotation',
                  value: options.rotation,
                  min: -90,
                  max: 90,
                  divisions: 36,
                  valueLabel: '${options.rotation.toInt()}°',
                  onChanged: (value) {
                    ref.read(watermarkOptionsProvider.notifier).state =
                        options.copyWith(rotation: value);
                  },
                ),

                // Color picker
                const SizedBox(height: 16),
                _ColorSelector(
                  selectedColor: options.fontColor,
                  onChanged: (color) {
                    ref.read(watermarkOptionsProvider.notifier).state =
                        options.copyWith(fontColor: color);
                  },
                ),

                const SizedBox(height: 32),

                // Add watermark button
                ElevatedButton.icon(
                  onPressed: () => _addWatermark(context, ref),
                  icon: const Icon(Icons.water_drop),
                  label: const Text('Add Watermark'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.watermarkColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is WatermarkProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Adding Watermark',
                ),
              ],

              // Success state
              if (state is WatermarkSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Watermark Added!',
                  subtitle: 'Your PDF now has the watermark applied',
                  onPrimaryAction: () => _shareResult(ref, state.outputPath),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Process Another',
                ),
              ],

              // Error state
              if (state is WatermarkErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Failed to Add Watermark',
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
      ref.read(watermarkFileProvider.notifier).state = files.first;
      ref.read(watermarkStateProvider.notifier).state =
          const WatermarkState.idle();
    }
  }

  Future<void> _addWatermark(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(watermarkFileProvider);
    final options = ref.read(watermarkOptionsProvider);
    final fileService = FileService();
    final processor = PdfProcessor();

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_watermarked',
    );

    final result = await processor.addWatermark(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      options: options,
      onProgress: (progress, step) {
        ref.read(watermarkStateProvider.notifier).state =
            WatermarkState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<String>) {
      ref.read(watermarkStateProvider.notifier).state =
          WatermarkState.success(result.data);

      // Add to recent files
      ref.read(recentFilesProvider.notifier).addFile(
        fileName: selectedFile.fileName,
        filePath: result.data,
        operation: 'Watermark',
        fileSize: selectedFile.fileSize,
      );
    } else if (result is OperationFailure<String>) {
      ref.read(watermarkStateProvider.notifier).state =
          WatermarkState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, String outputPath) async {
    final fileService = FileService();
    await fileService.shareFile(outputPath);
  }

  void _reset(WidgetRef ref) {
    ref.read(watermarkFileProvider.notifier).state = null;
    ref.read(watermarkStateProvider.notifier).state =
        const WatermarkState.idle();
  }
}

class _PositionGrid extends StatelessWidget {
  final WatermarkPosition selected;
  final ValueChanged<WatermarkPosition> onChanged;

  const _PositionGrid({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final positions = [
      [WatermarkPosition.topLeft, WatermarkPosition.topCenter, WatermarkPosition.topRight],
      [WatermarkPosition.centerLeft, WatermarkPosition.center, WatermarkPosition.centerRight],
      [WatermarkPosition.bottomLeft, WatermarkPosition.bottomCenter, WatermarkPosition.bottomRight],
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ...positions.map((row) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((pos) => _PositionButton(
              position: pos,
              isSelected: selected == pos,
              onTap: () => onChanged(pos),
            )).toList(),
          )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SpecialPositionButton(
                label: 'Diagonal',
                icon: Icons.rotate_right,
                isSelected: selected == WatermarkPosition.diagonal,
                onTap: () => onChanged(WatermarkPosition.diagonal),
              ),
              _SpecialPositionButton(
                label: 'Tile',
                icon: Icons.grid_view,
                isSelected: selected == WatermarkPosition.tile,
                onTap: () => onChanged(WatermarkPosition.tile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionButton extends StatelessWidget {
  final WatermarkPosition position;
  final bool isSelected;
  final VoidCallback onTap;

  const _PositionButton({
    required this.position,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.watermarkColor.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.watermarkColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.watermarkColor : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialPositionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpecialPositionButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.watermarkColor.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.watermarkColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.watermarkColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.watermarkColor : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderOption extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderOption({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
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
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.watermarkColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.watermarkColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ColorSelector extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onChanged;

  const _ColorSelector({
    required this.selectedColor,
    required this.onChanged,
  });

  static const _colors = [
    '#000000', // Black
    '#808080', // Gray
    '#FF0000', // Red
    '#00FF00', // Green
    '#0000FF', // Blue
    '#FFFF00', // Yellow
    '#FF00FF', // Magenta
    '#00FFFF', // Cyan
    '#FFA500', // Orange
    '#800080', // Purple
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((color) {
            final isSelected = color.toUpperCase() == selectedColor.toUpperCase();
            final colorValue = Color(int.parse(color.replaceAll('#', '0xFF')));
            return GestureDetector(
              onTap: () => onChanged(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorValue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.watermarkColor : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.watermarkColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
