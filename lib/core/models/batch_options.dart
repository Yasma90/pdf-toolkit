import 'package:pdf_toolkit/core/models/compression_level.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';

/// Batch operation types
enum BatchOperationType {
  compress,
  convert,
  protect,
  watermark,
  rotate,
  addPageNumbers,
}

/// Status of a batch item
enum BatchItemStatus {
  pending,
  processing,
  completed,
  failed,
}

/// Individual item in a batch operation
class BatchItem {
  final String id;
  final PdfFile file;
  final BatchItemStatus status;
  final double progress;
  final String? outputPath;
  final String? errorMessage;
  final int? originalSize;
  final int? resultSize;

  const BatchItem({
    required this.id,
    required this.file,
    this.status = BatchItemStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    this.originalSize,
    this.resultSize,
  });

  BatchItem copyWith({
    String? id,
    PdfFile? file,
    BatchItemStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    int? originalSize,
    int? resultSize,
  }) {
    return BatchItem(
      id: id ?? this.id,
      file: file ?? this.file,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      originalSize: originalSize ?? this.originalSize,
      resultSize: resultSize ?? this.resultSize,
    );
  }

  /// Calculate size reduction percentage
  double? get reductionPercent {
    if (originalSize == null || resultSize == null || originalSize == 0) {
      return null;
    }
    return ((originalSize! - resultSize!) / originalSize!) * 100;
  }
}

/// Options for batch operations
class BatchOptions {
  final BatchOperationType operationType;
  final CompressionOptions? compressionOptions;
  final WatermarkOptions? watermarkOptions;
  final RotateOptions? rotateOptions;
  final PageNumberOptions? pageNumberOptions;
  final int maxConcurrent;
  final bool stopOnError;

  const BatchOptions({
    required this.operationType,
    this.compressionOptions,
    this.watermarkOptions,
    this.rotateOptions,
    this.pageNumberOptions,
    this.maxConcurrent = 2,
    this.stopOnError = false,
  });
}

/// Watermark configuration
class WatermarkOptions {
  final WatermarkType type;
  final String text;
  final String? imagePath;
  final WatermarkPosition position;
  final double opacity;
  final double fontSize;
  final double rotation;
  final String fontColor;
  final bool allPages;
  final List<int>? specificPages;

  const WatermarkOptions({
    this.type = WatermarkType.text,
    this.text = 'CONFIDENTIAL',
    this.imagePath,
    this.position = WatermarkPosition.center,
    this.opacity = 0.3,
    this.fontSize = 48,
    this.rotation = -45,
    this.fontColor = '#808080',
    this.allPages = true,
    this.specificPages,
  });

  WatermarkOptions copyWith({
    WatermarkType? type,
    String? text,
    String? imagePath,
    WatermarkPosition? position,
    double? opacity,
    double? fontSize,
    double? rotation,
    String? fontColor,
    bool? allPages,
    List<int>? specificPages,
  }) {
    return WatermarkOptions(
      type: type ?? this.type,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      rotation: rotation ?? this.rotation,
      fontColor: fontColor ?? this.fontColor,
      allPages: allPages ?? this.allPages,
      specificPages: specificPages ?? this.specificPages,
    );
  }
}

enum WatermarkType { text, image }

enum WatermarkPosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  diagonal,
  tile,
}

/// Rotation options
class RotateOptions {
  final RotationAngle angle;
  final bool allPages;
  final List<int>? specificPages;

  const RotateOptions({
    this.angle = RotationAngle.clockwise90,
    this.allPages = true,
    this.specificPages,
  });

  RotateOptions copyWith({
    RotationAngle? angle,
    bool? allPages,
    List<int>? specificPages,
  }) {
    return RotateOptions(
      angle: angle ?? this.angle,
      allPages: allPages ?? this.allPages,
      specificPages: specificPages ?? this.specificPages,
    );
  }
}

enum RotationAngle {
  clockwise90(90, 'Rotate 90° →'),
  clockwise180(180, 'Rotate 180°'),
  clockwise270(270, 'Rotate 90° ←'),
  ;

  const RotationAngle(this.degrees, this.label);
  final int degrees;
  final String label;
}

/// Page number options
class PageNumberOptions {
  final PageNumberPosition position;
  final PageNumberFormat format;
  final int startNumber;
  final String prefix;
  final String suffix;
  final double fontSize;
  final String fontColor;
  final bool skipFirstPage;
  final List<int>? excludePages;

  const PageNumberOptions({
    this.position = PageNumberPosition.bottomCenter,
    this.format = PageNumberFormat.simple,
    this.startNumber = 1,
    this.prefix = '',
    this.suffix = '',
    this.fontSize = 12,
    this.fontColor = '#000000',
    this.skipFirstPage = false,
    this.excludePages,
  });

  PageNumberOptions copyWith({
    PageNumberPosition? position,
    PageNumberFormat? format,
    int? startNumber,
    String? prefix,
    String? suffix,
    double? fontSize,
    String? fontColor,
    bool? skipFirstPage,
    List<int>? excludePages,
  }) {
    return PageNumberOptions(
      position: position ?? this.position,
      format: format ?? this.format,
      startNumber: startNumber ?? this.startNumber,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      skipFirstPage: skipFirstPage ?? this.skipFirstPage,
      excludePages: excludePages ?? this.excludePages,
    );
  }

  /// Format page number string
  String formatPageNumber(int pageNum, int totalPages) {
    final num = startNumber + pageNum - 1;
    switch (format) {
      case PageNumberFormat.simple:
        return '$prefix$num$suffix';
      case PageNumberFormat.withTotal:
        return '$prefix$num / $totalPages$suffix';
      case PageNumberFormat.pageX:
        return '${prefix}Page $num$suffix';
      case PageNumberFormat.pageXOfY:
        return '${prefix}Page $num of $totalPages$suffix';
      case PageNumberFormat.roman:
        return '$prefix${_toRoman(num)}$suffix';
      case PageNumberFormat.letter:
        return '$prefix${_toLetter(num)}$suffix';
    }
  }

  String _toRoman(int num) {
    if (num <= 0 || num > 3999) return num.toString();
    const romanNumerals = [
      [1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'],
      [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'],
      [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']
    ];
    var result = '';
    var n = num;
    for (final pair in romanNumerals) {
      while (n >= (pair[0] as int)) {
        result += pair[1] as String;
        n -= pair[0] as int;
      }
    }
    return result;
  }

  String _toLetter(int num) {
    if (num <= 0) return num.toString();
    var result = '';
    var n = num;
    while (n > 0) {
      n--;
      result = String.fromCharCode(65 + (n % 26)) + result;
      n ~/= 26;
    }
    return result;
  }
}

enum PageNumberPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum PageNumberFormat {
  simple,       // 1, 2, 3
  withTotal,    // 1 / 10
  pageX,        // Page 1
  pageXOfY,     // Page 1 of 10
  roman,        // I, II, III
  letter,       // A, B, C
}

/// Result for batch operations
class BatchResult {
  final int totalFiles;
  final int successCount;
  final int failedCount;
  final int totalOriginalSize;
  final int totalResultSize;
  final Duration totalDuration;
  final List<BatchItem> items;

  const BatchResult({
    required this.totalFiles,
    required this.successCount,
    required this.failedCount,
    required this.totalOriginalSize,
    required this.totalResultSize,
    required this.totalDuration,
    required this.items,
  });

  double get overallReductionPercent {
    if (totalOriginalSize == 0) return 0;
    return ((totalOriginalSize - totalResultSize) / totalOriginalSize) * 100;
  }

  String get formattedOriginalSize => _formatSize(totalOriginalSize);
  String get formattedResultSize => _formatSize(totalResultSize);

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
