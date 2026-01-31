import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_processor.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';
import 'package:pdf_toolkit/core/providers/recent_files_provider.dart';

// Providers
final unlockFileProvider = StateProvider<PdfFile?>((ref) => null);
final unlockPasswordProvider = StateProvider<String>((ref) => '');
final unlockStateProvider = StateProvider<UnlockState>(
  (ref) => const UnlockState.idle(),
);

// State classes
sealed class UnlockState {
  const UnlockState();
  const factory UnlockState.idle() = UnlockIdleState;
  const factory UnlockState.processing(double progress, String? step) =
      UnlockProcessingState;
  const factory UnlockState.success(String outputPath) = UnlockSuccessState;
  const factory UnlockState.error(String message) = UnlockErrorState;
}

class UnlockIdleState extends UnlockState {
  const UnlockIdleState();
}

class UnlockProcessingState extends UnlockState {
  final double progress;
  final String? step;
  const UnlockProcessingState(this.progress, this.step);
}

class UnlockSuccessState extends UnlockState {
  final String outputPath;
  const UnlockSuccessState(this.outputPath);
}

class UnlockErrorState extends UnlockState {
  final String message;
  const UnlockErrorState(this.message);
}

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(unlockFileProvider);
    final state = ref.watch(unlockStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock PDF'),
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
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.unlockColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.unlockColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.unlockColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Remove password protection from your PDF. You\'ll need to know the current password.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.unlockColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // File selection
              FileDropZone(
                onTap: () => _selectFile(ref),
                selectedFileName: selectedFile?.fileName,
                fileSize: selectedFile?.formattedSize,
                onClear: selectedFile != null
                    ? () => ref.read(unlockFileProvider.notifier).state = null
                    : null,
                isLoading: state is UnlockProcessingState,
              ),

              if (selectedFile != null && state is! UnlockProcessingState) ...[
                const SizedBox(height: 32),

                // Locked indicator
                _LockedIndicator(),

                const SizedBox(height: 24),

                // Password input
                Text(
                  'Enter PDF Password',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter the current password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(unlockPasswordProvider.notifier).state = value;
                  },
                ),

                const SizedBox(height: 32),

                // Unlock button
                ElevatedButton.icon(
                  onPressed: _passwordController.text.isNotEmpty
                      ? () => _unlock(context, ref)
                      : null,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.unlockColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Processing state
              if (state is UnlockProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Unlocking PDF',
                ),
              ],

              // Success state
              if (state is UnlockSuccessState) ...[
                const SizedBox(height: 32),
                _SuccessAnimation(),
                const SizedBox(height: 24),
                ResultCard(
                  success: true,
                  title: 'PDF Unlocked!',
                  subtitle: 'Password protection has been removed',
                  onPrimaryAction: () => _shareResult(ref, state.outputPath),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Unlock Another',
                ),
              ],

              // Error state
              if (state is UnlockErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Unlock Failed',
                  subtitle: state.message,
                  onPrimaryAction: () {
                    ref.read(unlockStateProvider.notifier).state =
                        const UnlockState.idle();
                  },
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
      ref.read(unlockFileProvider.notifier).state = files.first;
      ref.read(unlockStateProvider.notifier).state = const UnlockState.idle();
      _passwordController.clear();
    }
  }

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(unlockFileProvider);
    final password = ref.read(unlockPasswordProvider);
    final fileService = FileService();
    final processor = PdfProcessor();

    if (selectedFile == null || password.isEmpty) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_unlocked',
    );

    final result = await processor.unlockPdf(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      password: password,
      onProgress: (progress, step) {
        ref.read(unlockStateProvider.notifier).state =
            UnlockState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<String>) {
      ref.read(unlockStateProvider.notifier).state =
          UnlockState.success(result.data);

      // Add to recent files
      ref.read(recentFilesProvider.notifier).addEntry(
        filePath: result.data,
        operation: 'Unlock',
      );
    } else if (result is OperationFailure<String>) {
      ref.read(unlockStateProvider.notifier).state =
          UnlockState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, String outputPath) async {
    final fileService = FileService();
    await fileService.shareFile(outputPath);
  }

  void _reset(WidgetRef ref) {
    ref.read(unlockFileProvider.notifier).state = null;
    ref.read(unlockPasswordProvider.notifier).state = '';
    ref.read(unlockStateProvider.notifier).state = const UnlockState.idle();
    _passwordController.clear();
  }
}

class _LockedIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.unlockColor.withOpacity(0.1),
            AppColors.unlockColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.unlockColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.unlockColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock,
              color: AppColors.unlockColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Protected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.unlockColor,
                    ),
              ),
              Text(
                'This PDF requires a password',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessAnimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open,
              color: AppColors.success,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatusIcon(Icons.lock, AppColors.unlockColor, strikethrough: true),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              _StatusIcon(Icons.lock_open, AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool strikethrough;

  const _StatusIcon(this.icon, this.color, {this.strikethrough = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        if (strikethrough)
          Container(
            width: 40,
            height: 2,
            color: color,
            transform: Matrix4.rotationZ(-0.5),
          ),
      ],
    );
  }
}
