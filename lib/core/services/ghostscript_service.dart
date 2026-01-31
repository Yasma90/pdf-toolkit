import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:pdf_toolkit/core/models/compression_level.dart';

/// Service for PDF compression using Ghostscript (Windows only)
///
/// Ghostscript provides professional-grade PDF compression with real
/// image quality reduction. This is significantly more effective than
/// Syncfusion's built-in compression for PDFs with embedded images.
///
/// Compression presets:
/// - screen: 72 dpi, lowest quality, smallest size
/// - ebook: 150 dpi, medium quality, good for digital
/// - printer: 300 dpi, high quality, for printing
/// - prepress: 300 dpi, highest quality, color preserved
class GhostscriptService {
  /// Path to bundled Ghostscript executable
  static String? _gsPath;

  /// Check if Ghostscript is available on this system
  static Future<bool> isAvailable() async {
    if (!Platform.isWindows) return false;

    final gsPath = await _findGhostscript();
    return gsPath != null;
  }

  /// Find Ghostscript executable
  static Future<String?> _findGhostscript() async {
    if (_gsPath != null) return _gsPath;

    // Check bundled location first (in app directory)
    final executableDir = path.dirname(Platform.resolvedExecutable);
    final bundledPaths = [
      path.join(executableDir, 'data', 'ghostscript', 'gswin64c.exe'),
      path.join(executableDir, 'ghostscript', 'gswin64c.exe'),
      path.join(executableDir, 'gs', 'gswin64c.exe'),
    ];

    for (final bundled in bundledPaths) {
      if (await File(bundled).exists()) {
        _gsPath = bundled;
        return _gsPath;
      }
    }

    // Check if Ghostscript is installed system-wide
    final systemPaths = [
      r'C:\Program Files\gs\gs10.05.1\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs10.04.0\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs10.03.1\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs10.02.1\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs10.01.2\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs10.00.0\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs9.56.1\bin\gswin64c.exe',
      r'C:\Program Files\gs\gs9.55.0\bin\gswin64c.exe',
      r'C:\Program Files (x86)\gs\gs10.05.1\bin\gswin32c.exe',
      r'C:\Program Files (x86)\gs\gs10.04.0\bin\gswin32c.exe',
    ];

    for (final systemPath in systemPaths) {
      if (await File(systemPath).exists()) {
        _gsPath = systemPath;
        return _gsPath;
      }
    }

    // Try to find via PATH
    try {
      final result = await Process.run('where', ['gswin64c.exe']);
      if (result.exitCode == 0) {
        final foundPath = result.stdout.toString().trim().split('\n').first;
        if (await File(foundPath).exists()) {
          _gsPath = foundPath;
          return _gsPath;
        }
      }
    } catch (_) {
      // where command failed
    }

    return null;
  }

  /// Compress a PDF file using Ghostscript
  ///
  /// Returns the path to the compressed file, or null if compression failed
  static Future<GhostscriptResult> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionLevel level,
    Function(String status)? onStatus,
  }) async {
    final gsPath = await _findGhostscript();
    if (gsPath == null) {
      return GhostscriptResult.error('Ghostscript not found');
    }

    onStatus?.call('Starting Ghostscript compression...');

    // Map compression level to Ghostscript preset and settings
    final pdfSettings = _getPdfSettings(level);
    final imageResolution = _getImageResolution(level);
    final jpegQuality = _getJpegQuality(level);

    // Build Ghostscript command with aggressive compression settings
    // Based on best practices from ghostscript.com/blog/optimizing-pdfs.html
    final args = [
      '-sDEVICE=pdfwrite',
      '-dCompatibilityLevel=1.4',
      '-dPDFSETTINGS=$pdfSettings',
      '-dNOPAUSE',
      '-dQUIET',
      '-dBATCH',
      '-dSAFER',
      // Preserve hyperlinks
      '-dPrinted=false',
      // Font optimization
      '-dEmbedAllFonts=true',
      '-dSubsetFonts=true',
      // Color image compression (JPEG)
      '-dAutoFilterColorImages=false',
      '-dColorImageFilter=/DCTEncode',
      '-dColorImageDownsampleType=/Bicubic',
      '-dColorImageResolution=$imageResolution',
      '-dColorImageDownsampleThreshold=1.0',
      // Gray image compression (JPEG)
      '-dAutoFilterGrayImages=false',
      '-dGrayImageFilter=/DCTEncode',
      '-dGrayImageDownsampleType=/Bicubic',
      '-dGrayImageResolution=$imageResolution',
      '-dGrayImageDownsampleThreshold=1.0',
      // Mono image compression
      '-dMonoImageDownsampleType=/Bicubic',
      '-dMonoImageResolution=${imageResolution ~/ 2}',
      '-dMonoImageDownsampleThreshold=1.0',
      // JPEG quality (0.0 to 1.0)
      '-dJPEGQ=$jpegQuality',
      // Additional optimizations
      '-dDetectDuplicateImages=true',
      '-dCompressFonts=true',
      '-dOptimize=true',
      // Don't preserve info that increases size
      '-dFastWebView=false',
      // Output file
      '-sOutputFile=$outputPath',
      // Input file
      inputPath,
    ];

    try {
      onStatus?.call('Compressing with Ghostscript ($pdfSettings)...');

      final result = await Process.run(gsPath, args);

      if (result.exitCode == 0) {
        // Verify output file exists
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputSize = await outputFile.length();
          return GhostscriptResult.success(outputPath, outputSize);
        } else {
          return GhostscriptResult.error('Output file not created');
        }
      } else {
        final errorMsg = result.stderr.toString();
        return GhostscriptResult.error(
          'Ghostscript failed: ${errorMsg.isEmpty ? 'Unknown error' : errorMsg}',
        );
      }
    } catch (e) {
      return GhostscriptResult.error('Failed to run Ghostscript: $e');
    }
  }

  /// Get Ghostscript PDF settings preset based on compression level
  static String _getPdfSettings(CompressionLevel level) {
    return switch (level) {
      CompressionLevel.low => '/ebook', // Good quality, reasonable size
      CompressionLevel.medium => '/ebook', // Balanced
      CompressionLevel.high => '/screen', // Aggressive compression
      CompressionLevel.extreme => '/screen', // Maximum compression
      CompressionLevel.custom => '/ebook',
    };
  }

  /// Get image resolution based on compression level
  static int _getImageResolution(CompressionLevel level) {
    return switch (level) {
      CompressionLevel.low => 200, // Good for printing
      CompressionLevel.medium => 150, // Good for screens
      CompressionLevel.high => 100, // Web quality
      CompressionLevel.extreme => 72, // Preview quality
      CompressionLevel.custom => 150,
    };
  }

  /// Get JPEG quality (0-100) based on compression level
  static int _getJpegQuality(CompressionLevel level) {
    return switch (level) {
      CompressionLevel.low => 85, // High quality JPEG
      CompressionLevel.medium => 70, // Good quality
      CompressionLevel.high => 50, // Moderate quality
      CompressionLevel.extreme => 30, // Low quality, max compression
      CompressionLevel.custom => 70,
    };
  }
}

/// Result of Ghostscript compression
class GhostscriptResult {
  final bool success;
  final String? outputPath;
  final int? outputSize;
  final String? error;

  const GhostscriptResult._({
    required this.success,
    this.outputPath,
    this.outputSize,
    this.error,
  });

  factory GhostscriptResult.success(String path, int size) {
    return GhostscriptResult._(
      success: true,
      outputPath: path,
      outputSize: size,
    );
  }

  factory GhostscriptResult.error(String message) {
    return GhostscriptResult._(
      success: false,
      error: message,
    );
  }
}
