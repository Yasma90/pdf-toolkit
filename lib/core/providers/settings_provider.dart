import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Provider for app settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// App settings model
class AppSettings {
  final ThemeMode themeMode;
  final String? outputDirectory;
  final bool openFileAfterProcess;
  final bool showNotifications;
  final String defaultCompressionLevel;
  final String defaultImageFormat;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.outputDirectory,
    this.openFileAfterProcess = true,
    this.showNotifications = true,
    this.defaultCompressionLevel = 'medium',
    this.defaultImageFormat = 'png',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? outputDirectory,
    bool? openFileAfterProcess,
    bool? showNotifications,
    String? defaultCompressionLevel,
    String? defaultImageFormat,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      openFileAfterProcess: openFileAfterProcess ?? this.openFileAfterProcess,
      showNotifications: showNotifications ?? this.showNotifications,
      defaultCompressionLevel:
          defaultCompressionLevel ?? this.defaultCompressionLevel,
      defaultImageFormat: defaultImageFormat ?? this.defaultImageFormat,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'outputDirectory': outputDirectory,
        'openFileAfterProcess': openFileAfterProcess,
        'showNotifications': showNotifications,
        'defaultCompressionLevel': defaultCompressionLevel,
        'defaultImageFormat': defaultImageFormat,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      outputDirectory: json['outputDirectory'] as String?,
      openFileAfterProcess: json['openFileAfterProcess'] as bool? ?? true,
      showNotifications: json['showNotifications'] as bool? ?? true,
      defaultCompressionLevel:
          json['defaultCompressionLevel'] as String? ?? 'medium',
      defaultImageFormat: json['defaultImageFormat'] as String? ?? 'png',
    );
  }
}

/// Notifier for managing settings state
class SettingsNotifier extends StateNotifier<AppSettings> {
  static const String _fileName = 'settings.json';

  SettingsNotifier() : super(const AppSettings()) {
    _loadFromStorage();
  }

  Future<String> get _storagePath async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'PDF Toolkit', _fileName);
  }

  Future<void> _loadFromStorage() async {
    try {
      final filePath = await _storagePath;
      final file = File(filePath);

      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        state = AppSettings.fromJson(json);
      }
    } catch (e) {
      // Use defaults
      state = const AppSettings();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final filePath = await _storagePath;
      final file = File(filePath);

      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveToStorage();
  }

  Future<void> setOutputDirectory(String? directory) async {
    state = state.copyWith(outputDirectory: directory);
    await _saveToStorage();
  }

  Future<void> setOpenFileAfterProcess(bool value) async {
    state = state.copyWith(openFileAfterProcess: value);
    await _saveToStorage();
  }

  Future<void> setShowNotifications(bool value) async {
    state = state.copyWith(showNotifications: value);
    await _saveToStorage();
  }

  Future<void> setDefaultCompressionLevel(String level) async {
    state = state.copyWith(defaultCompressionLevel: level);
    await _saveToStorage();
  }

  Future<void> setDefaultImageFormat(String format) async {
    state = state.copyWith(defaultImageFormat: format);
    await _saveToStorage();
  }
}
