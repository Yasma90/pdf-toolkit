import 'dart:io';
import 'package:path/path.dart' as path;

/// Represents a PDF file with its metadata
class PdfFile {
  final String filePath;
  final String fileName;
  final int sizeInBytes;
  final DateTime? lastModified;
  final int? pageCount;
  final bool isSelected;

  PdfFile({
    required this.filePath,
    required this.fileName,
    required this.sizeInBytes,
    this.lastModified,
    this.pageCount,
    this.isSelected = false,
  });

  /// Create from a File object
  static Future<PdfFile> fromFile(File file) async {
    final stat = await file.stat();
    return PdfFile(
      filePath: file.path,
      fileName: path.basename(file.path),
      sizeInBytes: stat.size,
      lastModified: stat.modified,
    );
  }

  /// Formatted file size string
  String get formattedSize {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Copy with modified properties
  PdfFile copyWith({
    String? filePath,
    String? fileName,
    int? sizeInBytes,
    DateTime? lastModified,
    int? pageCount,
    bool? isSelected,
  }) {
    return PdfFile(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastModified: lastModified ?? this.lastModified,
      pageCount: pageCount ?? this.pageCount,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfFile && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;
}
