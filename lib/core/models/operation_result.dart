/// Result of a PDF operation
sealed class OperationResult<T> {
  const OperationResult();
}

/// Successful operation result
class OperationSuccess<T> extends OperationResult<T> {
  final T data;
  final String? message;
  final Duration? duration;

  const OperationSuccess({
    required this.data,
    this.message,
    this.duration,
  });
}

/// Failed operation result
class OperationFailure<T> extends OperationResult<T> {
  final String error;
  final String? details;
  final StackTrace? stackTrace;

  const OperationFailure({
    required this.error,
    this.details,
    this.stackTrace,
  });
}

/// Operation in progress
class OperationProgress<T> extends OperationResult<T> {
  final double progress; // 0.0 to 1.0
  final String? currentStep;
  final int? currentPage;
  final int? totalPages;

  const OperationProgress({
    required this.progress,
    this.currentStep,
    this.currentPage,
    this.totalPages,
  });

  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';
}

/// Result specifically for compression operations
class CompressionResult {
  final String outputPath;
  final int originalSize;
  final int compressedSize;
  final Duration processingTime;

  const CompressionResult({
    required this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    required this.processingTime,
  });

  /// Size reduction as a percentage
  double get reductionPercent {
    if (originalSize == 0) return 0;
    return ((originalSize - compressedSize) / originalSize) * 100;
  }

  /// Formatted reduction string
  String get formattedReduction => '${reductionPercent.toStringAsFixed(1)}%';

  /// Formatted sizes
  String get formattedOriginalSize => _formatSize(originalSize);
  String get formattedCompressedSize => _formatSize(compressedSize);

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

/// Result for merge operations
class MergeResult {
  final String outputPath;
  final int totalPages;
  final int filesCount;
  final int outputSize;
  final Duration processingTime;

  const MergeResult({
    required this.outputPath,
    required this.totalPages,
    required this.filesCount,
    required this.outputSize,
    required this.processingTime,
  });
}

/// Result for split operations
class SplitResult {
  final List<String> outputPaths;
  final int totalFiles;
  final int totalSize;
  final Duration processingTime;

  const SplitResult({
    required this.outputPaths,
    required this.totalFiles,
    required this.totalSize,
    required this.processingTime,
  });
}
