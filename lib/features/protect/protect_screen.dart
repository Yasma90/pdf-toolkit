import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/models/security_options.dart';
import 'package:pdf_toolkit/core/services/file_service.dart';
import 'package:pdf_toolkit/core/services/pdf_service.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';
import 'package:pdf_toolkit/shared/widgets/file_drop_zone.dart';
import 'package:pdf_toolkit/shared/widgets/progress_card.dart';

// Providers
final protectFileServiceProvider = Provider((ref) => FileService());
final protectPdfServiceProvider = Provider((ref) => PdfService());

final protectSelectedFileProvider = StateProvider<PdfFile?>((ref) => null);
final passwordProvider = StateProvider<String>((ref) => '');
final confirmPasswordProvider = StateProvider<String>((ref) => '');
final ownerPasswordProvider = StateProvider<String?>((ref) => null);
final permissionPresetProvider = StateProvider<PermissionPreset>(
  (ref) => PermissionPreset.full,
);
final customPermissionsProvider = StateProvider<PdfPermissions>(
  (ref) => const PdfPermissions(),
);
final encryptionLevelProvider = StateProvider<EncryptionLevel>(
  (ref) => EncryptionLevel.aes256,
);
final protectStateProvider = StateProvider<ProtectState>(
  (ref) => const ProtectState.idle(),
);

// State classes
sealed class ProtectState {
  const ProtectState();
  const factory ProtectState.idle() = ProtectIdleState;
  const factory ProtectState.processing(double progress, String? step) =
      ProtectProcessingState;
  const factory ProtectState.success(ProtectionResult result) =
      ProtectSuccessState;
  const factory ProtectState.error(String message) = ProtectErrorState;
}

class ProtectIdleState extends ProtectState {
  const ProtectIdleState();
}

class ProtectProcessingState extends ProtectState {
  final double progress;
  final String? step;
  const ProtectProcessingState(this.progress, this.step);
}

class ProtectSuccessState extends ProtectState {
  final ProtectionResult result;
  const ProtectSuccessState(this.result);
}

class ProtectErrorState extends ProtectState {
  final String message;
  const ProtectErrorState(this.message);
}

class ProtectScreen extends ConsumerStatefulWidget {
  const ProtectScreen({super.key});

  @override
  ConsumerState<ProtectScreen> createState() => _ProtectScreenState();
}

class _ProtectScreenState extends ConsumerState<ProtectScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showAdvancedOptions = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(protectSelectedFileProvider);
    final permissionPreset = ref.watch(permissionPresetProvider);
    final encryptionLevel = ref.watch(encryptionLevelProvider);
    final state = ref.watch(protectStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect PDF'),
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
                    ? () => ref.read(protectSelectedFileProvider.notifier).state =
                        null
                    : null,
                isLoading: state is ProtectProcessingState,
              ),

              if (selectedFile != null && state is! ProtectProcessingState) ...[
                const SizedBox(height: 32),

                // Password section
                Text(
                  'Password Protection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter password to open PDF',
                  onChanged: (value) =>
                      ref.read(passwordProvider.notifier).state = value,
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  onChanged: (value) =>
                      ref.read(confirmPasswordProvider.notifier).state = value,
                ),

                const SizedBox(height: 24),

                // Permission presets
                Text(
                  'Permissions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                _PermissionPresetSelector(
                  selected: permissionPreset,
                  onChanged: (preset) {
                    ref.read(permissionPresetProvider.notifier).state = preset;
                  },
                ),

                // Custom permissions (expandable)
                if (permissionPreset == PermissionPreset.custom) ...[
                  const SizedBox(height: 16),
                  _CustomPermissionsPanel(
                    permissions: ref.watch(customPermissionsProvider),
                    onChanged: (perms) {
                      ref.read(customPermissionsProvider.notifier).state = perms;
                    },
                  ),
                ],

                // Advanced options
                const SizedBox(height: 24),
                ExpansionTile(
                  title: Text(
                    'Advanced Options',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _ownerPasswordController,
                      label: 'Owner Password (Optional)',
                      hint: 'Different from user password',
                      onChanged: (value) => ref
                          .read(ownerPasswordProvider.notifier)
                          .state = value.isEmpty ? null : value,
                    ),
                    const SizedBox(height: 16),
                    _EncryptionLevelSelector(
                      selected: encryptionLevel,
                      onChanged: (level) {
                        ref.read(encryptionLevelProvider.notifier).state = level;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Protect button
                ElevatedButton.icon(
                  onPressed: _canProtect() ? () => _protect(context, ref) : null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Protect PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.protectColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                if (!_canProtect() && _passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _getPasswordError(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],

              // Processing state
              if (state is ProtectProcessingState) ...[
                const SizedBox(height: 32),
                ProgressCard(
                  progress: state.progress,
                  currentStep: state.step,
                  title: 'Protecting PDF',
                ),
              ],

              // Success state
              if (state is ProtectSuccessState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: true,
                  title: 'Protection Complete!',
                  subtitle: 'Your PDF is now password protected',
                  stats: [
                    ResultStat(
                      label: 'Encryption',
                      value: state.result.encryptionLevel.name,
                    ),
                    ResultStat(
                      label: 'User Password',
                      value: state.result.hasUserPassword ? 'Set' : 'None',
                    ),
                    ResultStat(
                      label: 'Owner Password',
                      value: state.result.hasOwnerPassword ? 'Set' : 'Same as user',
                    ),
                  ],
                  onPrimaryAction: () => _shareResult(ref, state.result.outputPath),
                  primaryActionText: 'Share',
                  onSecondaryAction: () => _reset(ref),
                  secondaryActionText: 'Protect Another',
                ),
              ],

              // Error state
              if (state is ProtectErrorState) ...[
                const SizedBox(height: 32),
                ResultCard(
                  success: false,
                  title: 'Protection Failed',
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: !_showPassword,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
    );
  }

  bool _canProtect() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) return false;
    if (password.length < 4) return false;
    if (password != confirmPassword) return false;

    return true;
  }

  String _getPasswordError() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.length < 4) return 'Password must be at least 4 characters';
    if (password != confirmPassword) return 'Passwords do not match';

    return '';
  }

  Future<void> _selectFile(WidgetRef ref) async {
    final fileService = ref.read(protectFileServiceProvider);
    final files = await fileService.pickPdfFiles();
    if (files.isNotEmpty) {
      ref.read(protectSelectedFileProvider.notifier).state = files.first;
      ref.read(protectStateProvider.notifier).state = const ProtectState.idle();
    }
  }

  Future<void> _protect(BuildContext context, WidgetRef ref) async {
    final selectedFile = ref.read(protectSelectedFileProvider);
    final password = ref.read(passwordProvider);
    final ownerPassword = ref.read(ownerPasswordProvider);
    final permissionPreset = ref.read(permissionPresetProvider);
    final customPermissions = ref.read(customPermissionsProvider);
    final encryptionLevel = ref.read(encryptionLevelProvider);
    final fileService = ref.read(protectFileServiceProvider);
    final pdfService = ref.read(protectPdfServiceProvider);

    if (selectedFile == null) return;

    final outputPath = await fileService.generateOutputPath(
      inputPath: selectedFile.filePath,
      suffix: '_protected',
    );

    final permissions = permissionPreset == PermissionPreset.custom
        ? customPermissions
        : permissionPreset.permissions;

    final options = SecurityOptions(
      userPassword: password,
      ownerPassword: ownerPassword,
      permissions: permissions,
      encryptionLevel: encryptionLevel,
    );

    final result = await pdfService.protectPdf(
      inputPath: selectedFile.filePath,
      outputPath: outputPath,
      options: options,
      onProgress: (progress, step) {
        ref.read(protectStateProvider.notifier).state =
            ProtectState.processing(progress, step);
      },
    );

    if (result is OperationSuccess<ProtectionResult>) {
      ref.read(protectStateProvider.notifier).state =
          ProtectState.success(result.data);
    } else if (result is OperationFailure<ProtectionResult>) {
      ref.read(protectStateProvider.notifier).state =
          ProtectState.error(result.error);
    }
  }

  Future<void> _shareResult(WidgetRef ref, String outputPath) async {
    final fileService = ref.read(protectFileServiceProvider);
    await fileService.shareFile(outputPath);
  }

  void _reset(WidgetRef ref) {
    ref.read(protectSelectedFileProvider.notifier).state = null;
    ref.read(passwordProvider.notifier).state = '';
    ref.read(confirmPasswordProvider.notifier).state = '';
    ref.read(ownerPasswordProvider.notifier).state = null;
    ref.read(protectStateProvider.notifier).state = const ProtectState.idle();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _ownerPasswordController.clear();
  }
}

class _PermissionPresetSelector extends StatelessWidget {
  final PermissionPreset selected;
  final ValueChanged<PermissionPreset> onChanged;

  const _PermissionPresetSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: PermissionPreset.values.map((preset) {
        final isSelected = preset == selected;
        return GestureDetector(
          onTap: () => onChanged(preset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.protectColor.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.protectColor
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
                    Text(preset.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      preset.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppColors.protectColor : null,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  preset.description,
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

class _CustomPermissionsPanel extends StatelessWidget {
  final PdfPermissions permissions;
  final ValueChanged<PdfPermissions> onChanged;

  const _CustomPermissionsPanel({
    required this.permissions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _PermissionSwitch(
            title: 'Allow Printing',
            value: permissions.allowPrinting,
            onChanged: (v) => onChanged(permissions.copyWith(allowPrinting: v)),
          ),
          _PermissionSwitch(
            title: 'Allow Modifying',
            value: permissions.allowModifying,
            onChanged: (v) => onChanged(permissions.copyWith(allowModifying: v)),
          ),
          _PermissionSwitch(
            title: 'Allow Copying',
            value: permissions.allowCopying,
            onChanged: (v) => onChanged(permissions.copyWith(allowCopying: v)),
          ),
          _PermissionSwitch(
            title: 'Allow Annotations',
            value: permissions.allowAnnotations,
            onChanged: (v) =>
                onChanged(permissions.copyWith(allowAnnotations: v)),
          ),
          _PermissionSwitch(
            title: 'Allow Filling Forms',
            value: permissions.allowFillingForms,
            onChanged: (v) =>
                onChanged(permissions.copyWith(allowFillingForms: v)),
          ),
          _PermissionSwitch(
            title: 'Allow High Quality Print',
            value: permissions.allowHighQualityPrint,
            onChanged: (v) =>
                onChanged(permissions.copyWith(allowHighQualityPrint: v)),
          ),
        ],
      ),
    );
  }
}

class _PermissionSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.protectColor,
          ),
        ],
      ),
    );
  }
}

class _EncryptionLevelSelector extends StatelessWidget {
  final EncryptionLevel selected;
  final ValueChanged<EncryptionLevel> onChanged;

  const _EncryptionLevelSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encryption Level',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        ...EncryptionLevel.values.map((level) {
          final isSelected = level == selected;
          return RadioListTile<EncryptionLevel>(
            title: Text(level.name),
            subtitle: Text(level.description),
            value: level,
            groupValue: selected,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            activeColor: AppColors.protectColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
      ],
    );
  }
}
