import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_toolkit/core/models/pdf_file.dart';

/// Provider for recent files management
final recentFilesProvider =
    StateNotifierProvider<RecentFilesNotifier, List<RecentFileEntry>>((ref) {
  return RecentFilesNotifier();
});

/// Entry for a recent file with operation info
class RecentFileEntry {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String operation;
  final DateTime processedAt;
  final String? outputPath;

  RecentFileEntry({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.operation,
    required this.processedAt,
    this.outputPath,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(processedAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${processedAt.day}/${processedAt.month}/${processedAt.year}';
  }

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'operation': operation,
        'processedAt': processedAt.toIso8601String(),
        'outputPath': outputPath,
      };

  factory RecentFileEntry.fromJson(Map<String, dynamic> json) {
    return RecentFileEntry(
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      operation: json['operation'] as String,
      processedAt: DateTime.parse(json['processedAt'] as String),
      outputPath: json['outputPath'] as String?,
    );
  }
}

/// Notifier for managing recent files state
class RecentFilesNotifier extends StateNotifier<List<RecentFileEntry>> {
  static const int maxRecentFiles = 20;
  static const String _fileName = 'recent_files.json';

  RecentFilesNotifier() : super([]) {
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
        final List<dynamic> jsonList = jsonDecode(content);
        state = jsonList
            .map((json) => RecentFileEntry.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Silently fail - start with empty list
      state = [];
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final filePath = await _storagePath;
      final file = File(filePath);

      // Ensure directory exists
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final jsonList = state.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      // Silently fail
    }
  }

  /// Add a new recent file entry
  Future<void> addEntry({
    required String filePath,
    required String operation,
    String? outputPath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final stat = await file.stat();
      final entry = RecentFileEntry(
        filePath: filePath,
        fileName: path.basename(filePath),
        fileSize: stat.size,
        operation: operation,
        processedAt: DateTime.now(),
        outputPath: outputPath,
      );

      // Remove existing entry for same file
      final newList = state.where((e) => e.filePath != filePath).toList();

      // Add new entry at the beginning
      newList.insert(0, entry);

      // Limit to max entries
      if (newList.length > maxRecentFiles) {
        newList.removeRange(maxRecentFiles, newList.length);
      }

      state = newList;
      await _saveToStorage();
    } catch (e) {
      // Silently fail
    }
  }

  /// Remove a specific entry
  Future<void> removeEntry(String filePath) async {
    state = state.where((e) => e.filePath != filePath).toList();
    await _saveToStorage();
  }

  /// Clear all recent files
  Future<void> clearAll() async {
    state = [];
    await _saveToStorage();
  }
}
