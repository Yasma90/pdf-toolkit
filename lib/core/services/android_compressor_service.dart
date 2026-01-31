import 'dart:io';
import 'package:pdf_compressor/pdf_compressor.dart';
import 'package:pdf_toolkit/core/models/compression_level.dart';

/// Service for PDF compression on Android using native iText compression
///
/// This provides real PDF compression with image quality reduction on Android,
/// similar to what Ghostscript provides on Windows.
class AndroidCompressorService {
  /// Check if the Android compressor is available (only on Android)
  static Future<bool> isAvailable() async {
    return Platform.isAndroid;
  }

  /// Compress a PDF file using the native Android compressor
  ///
  /// Returns the result with output path and size, or error message
  static Future<AndroidCompressorResult> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionLevel level,
    Function(String status)? onStatus,
  }) async {
    if (!Platform.isAndroid) {
      return AndroidCompressorResult.error('Android compressor only available on Android');
    }

    try {
      onStatus?.call('Starting compression...');

      // Map compression level to CompressQuality
      final quality = _getCompressQuality(level);

      onStatus?.call('Compressing with ${quality.name} quality...');

      await PdfCompressor.compressPdfFile(
        inputPath,
        outputPath,
        quality,
      );

      // Verify output file exists
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        final outputSize = await outputFile.length();
        return AndroidCompressorResult.success(outputPath, outputSize);
      } else {
        return AndroidCompressorResult.error('Output file not created');
      }
    } catch (e) {
      return AndroidCompressorResult.error('Compression failed: $e');
    }
  }

  /// Map app compression level to pdf_compressor quality
  static CompressQuality _getCompressQuality(CompressionLevel level) {
    return switch (level) {
      CompressionLevel.low => CompressQuality.LOW,
      CompressionLevel.medium => CompressQuality.MEDIUM,
      CompressionLevel.high => CompressQuality.HIGH,
      CompressionLevel.extreme => CompressQuality.HIGH, // Maximum available
      CompressionLevel.custom => CompressQuality.MEDIUM,
    };
  }
}

/// Result of Android compression
class AndroidCompressorResult {
  final bool success;
  final String? outputPath;
  final int? outputSize;
  final String? error;

  const AndroidCompressorResult._({
    required this.success,
    this.outputPath,
    this.outputSize,
    this.error,
  });

  factory AndroidCompressorResult.success(String path, int size) {
    return AndroidCompressorResult._(
      success: true,
      outputPath: path,
      outputSize: size,
    );
  }

  factory AndroidCompressorResult.error(String message) {
    return AndroidCompressorResult._(
      success: false,
      error: message,
    );
  }
}
