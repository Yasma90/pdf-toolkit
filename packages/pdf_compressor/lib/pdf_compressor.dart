import 'dart:async';

import 'package:flutter/services.dart';

/// Compression level for PDF images
///
/// - LOW: Minimal compression, best quality (JPEG 85%, no resize)
/// - MEDIUM: Balanced compression (JPEG 60%, max 1200px)
/// - HIGH: Aggressive compression (JPEG 35%, max 800px)
/// - EXTREME: Maximum compression, lowest quality (JPEG 20%, max 600px)
enum CompressQuality { LOW, MEDIUM, HIGH, EXTREME }

class PdfCompressor {
  static const MethodChannel _channel = MethodChannel('pdf_compressor');

  /// Compress a PDF file with the specified quality level
  ///
  /// [inputPath] - Path to the input PDF file
  /// [outputPath] - Path where the compressed PDF will be saved
  /// [quality] - Compression level (LOW = best quality, EXTREME = smallest size)
  static Future<void> compressPdfFile(
      String inputPath, String outputPath, CompressQuality quality) async {
    final params = _getCompressionParams(quality);

    final Map<String, dynamic> args = <String, dynamic>{
      "inputPath": inputPath,
      "outputPath": outputPath,
      "quality": params.jpegQuality,
      "maxWidth": params.maxWidth,
      "maxHeight": params.maxHeight,
      "resizeImages": params.resizeImages,
    };

    return await _channel.invokeMethod('compressPdf', args);
  }

  /// Get compression parameters based on quality level
  static _CompressionParams _getCompressionParams(CompressQuality quality) {
    switch (quality) {
      case CompressQuality.LOW:
        // Minimal compression - preserve quality
        return _CompressionParams(
          jpegQuality: 85,
          maxWidth: 2400,
          maxHeight: 2400,
          resizeImages: false,
        );
      case CompressQuality.MEDIUM:
        // Balanced compression
        return _CompressionParams(
          jpegQuality: 60,
          maxWidth: 1200,
          maxHeight: 1200,
          resizeImages: true,
        );
      case CompressQuality.HIGH:
        // Aggressive compression - significant quality loss
        return _CompressionParams(
          jpegQuality: 35,
          maxWidth: 800,
          maxHeight: 800,
          resizeImages: true,
        );
      case CompressQuality.EXTREME:
        // Maximum compression - lowest quality
        return _CompressionParams(
          jpegQuality: 20,
          maxWidth: 600,
          maxHeight: 600,
          resizeImages: true,
        );
    }
  }
}

/// Internal class for compression parameters
class _CompressionParams {
  final int jpegQuality;
  final int maxWidth;
  final int maxHeight;
  final bool resizeImages;

  _CompressionParams({
    required this.jpegQuality,
    required this.maxWidth,
    required this.maxHeight,
    required this.resizeImages,
  });
}
