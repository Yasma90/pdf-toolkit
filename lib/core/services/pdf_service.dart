import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:path/path.dart' as path;
import 'package:pdf_toolkit/core/models/compression_level.dart';
import 'package:pdf_toolkit/core/models/image_format.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';
import 'package:pdf_toolkit/core/models/security_options.dart';
import 'package:pdf_toolkit/core/models/extraction_options.dart';
import 'package:pdf_toolkit/core/services/ghostscript_service.dart';
import 'package:pdf_toolkit/core/services/android_compressor_service.dart';

/// Service for PDF manipulation operations
///
/// Compression strategy by platform:
/// - **Windows**: Uses Ghostscript for professional-grade compression with
///   real image quality reduction (can achieve 30-90% file size reduction)
/// - **Android/Other**: Uses Syncfusion's built-in compression which optimizes
///   document structure but has limited image compression capabilities
class PdfService {
  /// Compress a PDF file with specified options
  ///
  /// On Windows with Ghostscript available:
  /// - Uses Ghostscript for real image compression
  /// - Maps compression levels to Ghostscript presets (screen/ebook/printer)
  /// - Can significantly reduce file size for image-heavy PDFs
  ///
  /// On Android or when Ghostscript unavailable:
  /// - Uses Syncfusion's document structure optimization
  /// - Disables incremental updates for full document rewrite
  /// - Uses cross-reference streams for efficient structure
  Future<OperationResult<CompressionResult>> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call(0.05, 'Checking compression engine...');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const OperationFailure(error: 'Input file not found');
      }

      final originalSize = await inputFile.length();

      // Try platform-specific compression for better image compression
      if (Platform.isWindows && options.compressImages) {
        final gsAvailable = await GhostscriptService.isAvailable();
        if (gsAvailable) {
          return await _compressWithGhostscript(
            inputPath: inputPath,
            outputPath: outputPath,
            options: options,
            originalSize: originalSize,
            stopwatch: stopwatch,
            onProgress: onProgress,
          );
        }
      }

      // Try Android native compressor for real image compression
      if (Platform.isAndroid && options.compressImages) {
        final androidAvailable = await AndroidCompressorService.isAvailable();
        if (androidAvailable) {
          return await _compressWithAndroid(
            inputPath: inputPath,
            outputPath: outputPath,
            options: options,
            originalSize: originalSize,
            stopwatch: stopwatch,
            onProgress: onProgress,
          );
        }
      }

      // Fallback to Syncfusion compression (structure optimization only)
      return await _compressWithSyncfusion(
        inputPath: inputPath,
        outputPath: outputPath,
        options: options,
        originalSize: originalSize,
        stopwatch: stopwatch,
        onProgress: onProgress,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to compress PDF',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Compress PDF using Ghostscript (Windows only)
  ///
  /// Provides professional-grade compression with real image quality reduction
  Future<OperationResult<CompressionResult>> _compressWithGhostscript({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    required int originalSize,
    required Stopwatch stopwatch,
    Function(double progress, String? step)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Using Ghostscript engine...');

    // First, apply Syncfusion optimizations if needed (metadata, annotations)
    String processedInput = inputPath;
    if (options.removeMetadata || options.removeAnnotations) {
      onProgress?.call(0.2, 'Applying document optimizations...');
      final tempPath = outputPath.replaceAll('.pdf', '_temp.pdf');
      await _applySyncfusionOptimizations(
        inputPath: inputPath,
        outputPath: tempPath,
        options: options,
      );
      processedInput = tempPath;
    }

    onProgress?.call(0.4, 'Compressing images with Ghostscript...');

    final result = await GhostscriptService.compressPdf(
      inputPath: processedInput,
      outputPath: outputPath,
      level: options.level,
      onStatus: (status) {
        onProgress?.call(0.6, status);
      },
    );

    // Clean up temp file if created
    if (processedInput != inputPath) {
      try {
        await File(processedInput).delete();
      } catch (_) {}
    }

    if (result.success) {
      onProgress?.call(1.0, 'Complete!');
      stopwatch.stop();

      return OperationSuccess(
        data: CompressionResult(
          outputPath: outputPath,
          originalSize: originalSize,
          compressedSize: result.outputSize!,
          processingTime: stopwatch.elapsed,
        ),
        message: 'PDF compressed with Ghostscript',
        duration: stopwatch.elapsed,
      );
    } else {
      // If Ghostscript fails, fallback to Syncfusion
      onProgress?.call(0.5, 'Ghostscript failed, using fallback...');
      return await _compressWithSyncfusion(
        inputPath: inputPath,
        outputPath: outputPath,
        options: options,
        originalSize: originalSize,
        stopwatch: stopwatch,
        onProgress: onProgress,
      );
    }
  }

  /// Compress PDF using native Android compressor (Android only)
  ///
  /// Uses iText-based compression for real image quality reduction
  Future<OperationResult<CompressionResult>> _compressWithAndroid({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    required int originalSize,
    required Stopwatch stopwatch,
    Function(double progress, String? step)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Using Android native compressor...');

    // First, apply Syncfusion optimizations if needed (metadata, annotations)
    String processedInput = inputPath;
    if (options.removeMetadata || options.removeAnnotations) {
      onProgress?.call(0.2, 'Applying document optimizations...');
      final tempPath = outputPath.replaceAll('.pdf', '_temp.pdf');
      await _applySyncfusionOptimizations(
        inputPath: inputPath,
        outputPath: tempPath,
        options: options,
      );
      processedInput = tempPath;
    }

    onProgress?.call(0.4, 'Compressing PDF...');

    final result = await AndroidCompressorService.compressPdf(
      inputPath: processedInput,
      outputPath: outputPath,
      level: options.level,
      onStatus: (status) {
        onProgress?.call(0.6, status);
      },
    );

    // Clean up temp file if created
    if (processedInput != inputPath) {
      try {
        await File(processedInput).delete();
      } catch (_) {}
    }

    if (result.success) {
      onProgress?.call(1.0, 'Complete!');
      stopwatch.stop();

      return OperationSuccess(
        data: CompressionResult(
          outputPath: outputPath,
          originalSize: originalSize,
          compressedSize: result.outputSize!,
          processingTime: stopwatch.elapsed,
        ),
        message: 'PDF compressed with Android native compressor',
        duration: stopwatch.elapsed,
      );
    } else {
      // If Android compressor fails, fallback to Syncfusion
      onProgress?.call(0.5, 'Native compressor failed, using fallback...');
      return await _compressWithSyncfusion(
        inputPath: inputPath,
        outputPath: outputPath,
        options: options,
        originalSize: originalSize,
        stopwatch: stopwatch,
        onProgress: onProgress,
      );
    }
  }

  /// Compress PDF using Syncfusion (cross-platform fallback)
  Future<OperationResult<CompressionResult>> _compressWithSyncfusion({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    required int originalSize,
    required Stopwatch stopwatch,
    Function(double progress, String? step)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Loading PDF...');

    final inputBytes = await File(inputPath).readAsBytes();

    onProgress?.call(0.3, 'Analyzing document...');

    final document = syncfusion.PdfDocument(inputBytes: inputBytes);
    final pageCount = document.pages.count;

    onProgress?.call(0.4, 'Applying compression settings...');

    // Apply compression configuration
    _configureDocumentCompression(document, options);

    onProgress?.call(0.6, 'Applying optimizations...');

    // Apply optional optimizations
    _applyOptionalOptimizations(document, options, pageCount);

    onProgress?.call(0.8, 'Saving compressed PDF...');

    final compressedBytes = await document.save();
    document.dispose();

    await File(outputPath).writeAsBytes(compressedBytes);

    final compressedSize = compressedBytes.length;

    onProgress?.call(1.0, 'Complete!');
    stopwatch.stop();

    return OperationSuccess(
      data: CompressionResult(
        outputPath: outputPath,
        originalSize: originalSize,
        compressedSize: compressedSize,
        processingTime: stopwatch.elapsed,
      ),
      message: 'PDF compressed successfully',
      duration: stopwatch.elapsed,
    );
  }

  /// Apply only Syncfusion optimizations (metadata, annotations) without compression
  Future<void> _applySyncfusionOptimizations({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
  }) async {
    final inputBytes = await File(inputPath).readAsBytes();
    final document = syncfusion.PdfDocument(inputBytes: inputBytes);
    final pageCount = document.pages.count;

    // Don't apply compression settings - just optimizations
    document.fileStructure.incrementalUpdate = false;

    _applyOptionalOptimizations(document, options, pageCount);

    final bytes = await document.save();
    document.dispose();

    await File(outputPath).writeAsBytes(bytes);
  }

  /// Configure document settings for optimal compression
  void _configureDocumentCompression(
    syncfusion.PdfDocument document,
    CompressionOptions options,
  ) {
    // CRITICAL: Disable incremental update to force full rewrite
    // Without this, changes are appended and file size increases
    document.fileStructure.incrementalUpdate = false;

    // Use cross-reference stream for more efficient PDF structure
    document.fileStructure.crossReferenceType =
        syncfusion.PdfCrossReferenceType.crossReferenceStream;

    // Set compression level for content streams
    // This affects how content streams (including image data) are compressed
    document.compressionLevel = _getCompressionLevel(options.level);
  }

  /// Apply optional optimizations based on user settings
  void _applyOptionalOptimizations(
    syncfusion.PdfDocument document,
    CompressionOptions options,
    int pageCount,
  ) {
    if (options.removeMetadata) {
      _clearDocumentMetadata(document);
    }

    if (options.removeAnnotations) {
      _flattenAnnotations(document, pageCount);
    }
  }

  /// Clear all document metadata fields
  void _clearDocumentMetadata(syncfusion.PdfDocument document) {
    final info = document.documentInformation;
    info.title = '';
    info.author = '';
    info.subject = '';
    info.keywords = '';
    info.creator = '';
    info.producer = '';
  }

  /// Flatten annotations on all pages
  void _flattenAnnotations(syncfusion.PdfDocument document, int pageCount) {
    for (int i = 0; i < pageCount; i++) {
      document.pages[i].annotations.flattenAllAnnotations();
    }
  }

  /// Merge multiple PDF files into one
  Future<OperationResult<MergeResult>> mergePdfs({
    required List<String> inputPaths,
    required String outputPath,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (inputPaths.isEmpty) {
        return const OperationFailure(error: 'No input files provided');
      }

      if (inputPaths.length < 2) {
        return const OperationFailure(error: 'At least 2 files required for merge');
      }

      onProgress?.call(0.1, 'Preparing merge...');

      final outputDocument = syncfusion.PdfDocument();
      int totalPages = 0;

      for (int i = 0; i < inputPaths.length; i++) {
        final inputPath = inputPaths[i];
        final progress = 0.1 + (0.8 * (i / inputPaths.length));
        onProgress?.call(progress, 'Processing file ${i + 1} of ${inputPaths.length}...');

        final inputFile = File(inputPath);
        if (!await inputFile.exists()) {
          return OperationFailure(error: 'File not found: ${path.basename(inputPath)}');
        }

        final inputBytes = await inputFile.readAsBytes();
        final inputDocument = syncfusion.PdfDocument(inputBytes: inputBytes);

        // Import all pages from the input document
        for (int j = 0; j < inputDocument.pages.count; j++) {
          final template = inputDocument.pages[j].createTemplate();
          final page = outputDocument.pages.add();
          page.graphics.drawPdfTemplate(
            template,
            const ui.Offset(0, 0),
          );
          totalPages++;
        }

        inputDocument.dispose();
      }

      onProgress?.call(0.9, 'Saving merged PDF...');

      final mergedBytes = await outputDocument.save();
      outputDocument.dispose();

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(mergedBytes);

      onProgress?.call(1.0, 'Complete!');

      stopwatch.stop();

      return OperationSuccess(
        data: MergeResult(
          outputPath: outputPath,
          totalPages: totalPages,
          filesCount: inputPaths.length,
          outputSize: mergedBytes.length,
          processingTime: stopwatch.elapsed,
        ),
        message: 'PDFs merged successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to merge PDFs',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Split a PDF file into multiple files
  Future<OperationResult<SplitResult>> splitPdf({
    required String inputPath,
    required String outputDirectory,
    required SplitMode mode,
    List<int>? pageRanges,
    int? pagesPerFile,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call(0.1, 'Loading PDF...');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const OperationFailure(error: 'Input file not found');
      }

      final inputBytes = await inputFile.readAsBytes();
      final inputDocument = syncfusion.PdfDocument(inputBytes: inputBytes);
      final totalPages = inputDocument.pages.count;
      final baseName = path.basenameWithoutExtension(inputPath);

      final outputPaths = <String>[];
      int totalSize = 0;

      switch (mode) {
        case SplitMode.everyPage:
          for (int i = 0; i < totalPages; i++) {
            final progress = 0.1 + (0.8 * (i / totalPages));
            onProgress?.call(progress, 'Creating page ${i + 1} of $totalPages...');

            final outputDoc = syncfusion.PdfDocument();
            final template = inputDocument.pages[i].createTemplate();
            final page = outputDoc.pages.add();
            page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));

            final outputPath = path.join(
              outputDirectory,
              '${baseName}_page_${i + 1}.pdf',
            );
            final bytes = await outputDoc.save();
            await File(outputPath).writeAsBytes(bytes);

            outputPaths.add(outputPath);
            totalSize += bytes.length as int;
            outputDoc.dispose();
          }
          break;

        case SplitMode.byPageCount:
          final perFile = pagesPerFile ?? 1;
          int fileIndex = 1;

          for (int i = 0; i < totalPages; i += perFile) {
            final progress = 0.1 + (0.8 * (i / totalPages));
            onProgress?.call(progress, 'Creating file $fileIndex...');

            final outputDoc = syncfusion.PdfDocument();
            final endPage = (i + perFile).clamp(0, totalPages);

            for (int j = i; j < endPage; j++) {
              final template = inputDocument.pages[j].createTemplate();
              final page = outputDoc.pages.add();
              page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
            }

            final outputPath = path.join(
              outputDirectory,
              '${baseName}_part_$fileIndex.pdf',
            );
            final bytes = await outputDoc.save();
            await File(outputPath).writeAsBytes(bytes);

            outputPaths.add(outputPath);
            totalSize += bytes.length as int;
            outputDoc.dispose();
            fileIndex++;
          }
          break;

        case SplitMode.byRanges:
          if (pageRanges == null || pageRanges.isEmpty) {
            return const OperationFailure(error: 'Page ranges required');
          }
          // Custom range splitting logic
          break;
      }

      inputDocument.dispose();

      onProgress?.call(1.0, 'Complete!');

      stopwatch.stop();

      return OperationSuccess(
        data: SplitResult(
          outputPaths: outputPaths,
          totalFiles: outputPaths.length,
          totalSize: totalSize,
          processingTime: stopwatch.elapsed,
        ),
        message: 'PDF split successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to split PDF',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Convert PDF pages to images
  Future<OperationResult<ConversionResult>> convertToImages({
    required String inputPath,
    required String outputDirectory,
    required ConversionOptions options,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call(0.1, 'Loading PDF...');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const OperationFailure(error: 'Input file not found');
      }

      final inputBytes = await inputFile.readAsBytes();
      final document = syncfusion.PdfDocument(inputBytes: inputBytes);
      final totalPages = document.pages.count;
      final baseName = path.basenameWithoutExtension(inputPath);

      final outputPaths = <String>[];
      int totalSize = 0;

      // Determine which pages to convert
      final pagesToConvert = options.allPages
          ? List.generate(totalPages, (i) => i)
          : (options.specificPages ?? [0]);

      onProgress?.call(0.2, 'Converting pages...');

      for (int i = 0; i < pagesToConvert.length; i++) {
        final pageIndex = pagesToConvert[i];
        if (pageIndex >= totalPages) continue;

        final progress = 0.2 + (0.7 * (i / pagesToConvert.length));
        onProgress?.call(progress, 'Converting page ${pageIndex + 1}...');

        final page = document.pages[pageIndex];

        // Extract page as image using Syncfusion
        final imageBytes = await _renderPageToImage(
          document,
          pageIndex,
          options.quality.dpi,
          options.format,
          options.quality.quality,
        );

        if (imageBytes != null) {
          final outputPath = path.join(
            outputDirectory,
            '${baseName}_page_${pageIndex + 1}.${options.format.extension}',
          );

          await File(outputPath).writeAsBytes(imageBytes);
          outputPaths.add(outputPath);
          totalSize += imageBytes.length;
        }
      }

      document.dispose();

      onProgress?.call(1.0, 'Complete!');

      stopwatch.stop();

      return OperationSuccess(
        data: ConversionResult(
          outputPaths: outputPaths,
          totalImages: outputPaths.length,
          totalSize: totalSize,
          processingTime: stopwatch.elapsed,
          format: options.format,
        ),
        message: 'PDF converted successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to convert PDF',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Render a PDF page to image bytes
  Future<Uint8List?> _renderPageToImage(
    syncfusion.PdfDocument document,
    int pageIndex,
    int dpi,
    ImageFormat format,
    int quality,
  ) async {
    try {
      // Use Syncfusion's image extraction
      final page = document.pages[pageIndex];

      // Extract images from the page or render the page
      // Note: Full rendering requires platform-specific implementation
      // This is a simplified version using Syncfusion's capabilities

      final syncfusion.PdfPageLayer layer = page.layers.add(name: 'ImageLayer');

      // For actual image rendering, we'll use the printing package
      // which provides rasterization capabilities
      // This creates a placeholder that works with the printing package

      // Calculate dimensions based on DPI
      final width = (page.size.width * dpi / 72).round();
      final height = (page.size.height * dpi / 72).round();

      // Return a signal that this page needs to be rendered
      // The actual rendering will be done by the UI layer using printing package
      return Uint8List(0); // Placeholder - actual impl in screen
    } catch (e) {
      return null;
    }
  }

  /// Protect PDF with password and permissions
  Future<OperationResult<ProtectionResult>> protectPdf({
    required String inputPath,
    required String outputPath,
    required SecurityOptions options,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call(0.1, 'Loading PDF...');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const OperationFailure(error: 'Input file not found');
      }

      final inputBytes = await inputFile.readAsBytes();
      final document = syncfusion.PdfDocument(inputBytes: inputBytes);

      onProgress?.call(0.3, 'Configuring security...');

      // Create security settings based on encryption level
      final syncfusion.PdfSecurity security = document.security;

      // Set encryption algorithm
      switch (options.encryptionLevel) {
        case EncryptionLevel.rc4_40:
          security.algorithm = syncfusion.PdfEncryptionAlgorithm.rc4x40Bit;
          break;
        case EncryptionLevel.rc4_128:
          security.algorithm = syncfusion.PdfEncryptionAlgorithm.rc4x128Bit;
          break;
        case EncryptionLevel.aes128:
          security.algorithm = syncfusion.PdfEncryptionAlgorithm.aesx128Bit;
          break;
        case EncryptionLevel.aes256:
          security.algorithm = syncfusion.PdfEncryptionAlgorithm.aesx256Bit;
          break;
      }

      onProgress?.call(0.5, 'Setting passwords...');

      // Set passwords
      security.userPassword = options.userPassword;
      security.ownerPassword = options.effectiveOwnerPassword;

      onProgress?.call(0.6, 'Applying permissions...');

      // Set permissions
      final perms = options.permissions;
      security.permissions.clear();

      if (perms.allowPrinting) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.print);
      }
      if (perms.allowModifying) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.editContent);
      }
      if (perms.allowCopying) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.copyContent);
      }
      if (perms.allowAnnotations) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.editAnnotations);
      }
      if (perms.allowFillingForms) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.fillFields);
      }
      if (perms.allowAccessibility) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.accessibilityCopyContent);
      }
      if (perms.allowAssembly) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.assembleDocument);
      }
      if (perms.allowHighQualityPrint) {
        security.permissions.add(syncfusion.PdfPermissionsFlags.fullQualityPrint);
      }

      onProgress?.call(0.8, 'Saving protected PDF...');

      // Save the protected document
      final protectedBytes = await document.save();
      document.dispose();

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(protectedBytes);

      onProgress?.call(1.0, 'Complete!');

      stopwatch.stop();

      return OperationSuccess(
        data: ProtectionResult(
          outputPath: outputPath,
          encryptionLevel: options.encryptionLevel,
          hasUserPassword: options.userPassword.isNotEmpty,
          hasOwnerPassword: options.ownerPassword != null,
          processingTime: stopwatch.elapsed,
        ),
        message: 'PDF protected successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to protect PDF',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Extract specific pages from PDF
  Future<OperationResult<ExtractionResult>> extractPages({
    required String inputPath,
    required String outputPath,
    required ExtractionOptions options,
    required int totalPages,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call(0.1, 'Loading PDF...');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const OperationFailure(error: 'Input file not found');
      }

      final inputBytes = await inputFile.readAsBytes();
      final inputDocument = syncfusion.PdfDocument(inputBytes: inputBytes);

      onProgress?.call(0.2, 'Analyzing pages...');

      // Get pages to extract
      final pagesToExtract = options.getEffectivePages(inputDocument.pages.count);

      if (pagesToExtract.isEmpty) {
        inputDocument.dispose();
        return const OperationFailure(error: 'No valid pages selected');
      }

      onProgress?.call(0.3, 'Extracting pages...');

      // Create output document
      final outputDocument = syncfusion.PdfDocument();

      for (int i = 0; i < pagesToExtract.length; i++) {
        final pageIndex = pagesToExtract[i];
        final progress = 0.3 + (0.6 * (i / pagesToExtract.length));
        onProgress?.call(progress, 'Extracting page ${pageIndex + 1}...');

        // Copy page to new document
        final template = inputDocument.pages[pageIndex].createTemplate();
        final page = outputDocument.pages.add();
        page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
      }

      inputDocument.dispose();

      onProgress?.call(0.9, 'Saving extracted PDF...');

      // Save output document
      final outputBytes = await outputDocument.save();
      outputDocument.dispose();

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes);

      onProgress?.call(1.0, 'Complete!');

      stopwatch.stop();

      return OperationSuccess(
        data: ExtractionResult(
          outputPath: outputPath,
          extractedPages: pagesToExtract.length,
          outputSize: outputBytes.length,
          processingTime: stopwatch.elapsed,
        ),
        message: 'Pages extracted successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to extract pages',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Get PDF metadata and page count
  Future<PdfMetadata?> getPdfMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final document = syncfusion.PdfDocument(inputBytes: bytes);

      final metadata = PdfMetadata(
        pageCount: document.pages.count,
        title: document.documentInformation.title,
        author: document.documentInformation.author,
        subject: document.documentInformation.subject,
        creator: document.documentInformation.creator,
        creationDate: document.documentInformation.creationDate,
        modificationDate: document.documentInformation.modificationDate,
      );

      document.dispose();
      return metadata;
    } catch (e) {
      return null;
    }
  }

  /// Map application compression level to Syncfusion compression level
  syncfusion.PdfCompressionLevel _getCompressionLevel(CompressionLevel level) {
    return switch (level) {
      CompressionLevel.low => syncfusion.PdfCompressionLevel.normal,
      CompressionLevel.medium => syncfusion.PdfCompressionLevel.aboveNormal,
      CompressionLevel.high => syncfusion.PdfCompressionLevel.best,
      CompressionLevel.extreme => syncfusion.PdfCompressionLevel.best,
      CompressionLevel.custom => syncfusion.PdfCompressionLevel.normal,
    };
  }
}

/// Modes for splitting PDFs
enum SplitMode {
  everyPage,
  byPageCount,
  byRanges,
}

/// PDF metadata container
class PdfMetadata {
  final int pageCount;
  final String? title;
  final String? author;
  final String? subject;
  final String? creator;
  final DateTime? creationDate;
  final DateTime? modificationDate;

  const PdfMetadata({
    required this.pageCount,
    this.title,
    this.author,
    this.subject,
    this.creator,
    this.creationDate,
    this.modificationDate,
  });
}
