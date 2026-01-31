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

    // Map compression level to Ghostscript preset
    final pdfSettings = _getPdfSettings(level);
    final imageResolution = _getImageResolution(level);

    // Build Ghostscript command
    final args = [
      '-sDEVICE=pdfwrite',
      '-dCompatibilityLevel=1.4',
      '-dPDFSETTINGS=$pdfSettings',
      '-dNOPAUSE',
      '-dQUIET',
      '-dBATCH',
      // Image compression settings
      '-dColorImageDownsampleType=/Bicubic',
      '-dColorImageResolution=$imageResolution',
      '-dGrayImageDownsampleType=/Bicubic',
      '-dGrayImageResolution=$imageResolution',
      '-dMonoImageDownsampleType=/Bicubic',
      '-dMonoImageResolution=${imageResolution ~/ 2}',
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
      CompressionLevel.low => '/printer', // 300 dpi, high quality
      CompressionLevel.medium => '/ebook', // 150 dpi, good quality
      CompressionLevel.high => '/ebook', // 150 dpi with lower resolution
      CompressionLevel.extreme => '/screen', // 72 dpi, lowest quality
      CompressionLevel.custom => '/ebook',
    };
  }

  /// Get image resolution based on compression level
  static int _getImageResolution(CompressionLevel level) {
    return switch (level) {
      CompressionLevel.low => 300,
      CompressionLevel.medium => 150,
      CompressionLevel.high => 120,
      CompressionLevel.extreme => 72,
      CompressionLevel.custom => 150,
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
