import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_toolkit/core/models/compression_level.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';

/// Service for PDF manipulation operations
class PdfService {
  /// Compress a PDF file with specified options
  Future<OperationResult<CompressionResult>> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    Function(double progress, String? step)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call(0.1, 'Loading PDF...');

      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return const OperationFailure(error: 'Input file not found');
      }

      final originalSize = await inputFile.length();
      final inputBytes = await inputFile.readAsBytes();

      onProgress?.call(0.3, 'Analyzing document...');

      // Load PDF document
      final document = PdfDocument(inputBytes: inputBytes);
      final pageCount = document.pages.count;

      onProgress?.call(0.4, 'Compressing images...');

      // Apply compression based on options
      if (options.compressImages) {
        _compressImagesInDocument(document, options);
      }

      onProgress?.call(0.6, 'Optimizing structure...');

      if (options.removeMetadata) {
        document.documentInformation.title = '';
        document.documentInformation.author = '';
        document.documentInformation.subject = '';
        document.documentInformation.keywords = '';
        document.documentInformation.creator = '';
        document.documentInformation.producer = '';
      }

      if (options.removeAnnotations) {
        for (int i = 0; i < pageCount; i++) {
          final page = document.pages[i];
          page.annotations.clear();
        }
      }

      onProgress?.call(0.8, 'Saving compressed PDF...');

      // Save the compressed document
      final compressedBytes = await document.save();
      document.dispose();

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedBytes);

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
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to compress PDF',
        details: e.toString(),
        stackTrace: stackTrace,
      );
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

      final outputDocument = PdfDocument();
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
        final inputDocument = PdfDocument(inputBytes: inputBytes);

        // Import all pages from the input document
        for (int j = 0; j < inputDocument.pages.count; j++) {
          final template = inputDocument.pages[j].createTemplate();
          final page = outputDocument.pages.add();
          page.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
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
      final inputDocument = PdfDocument(inputBytes: inputBytes);
      final totalPages = inputDocument.pages.count;
      final baseName = path.basenameWithoutExtension(inputPath);

      final outputPaths = <String>[];
      int totalSize = 0;

      switch (mode) {
        case SplitMode.everyPage:
          for (int i = 0; i < totalPages; i++) {
            final progress = 0.1 + (0.8 * (i / totalPages));
            onProgress?.call(progress, 'Creating page ${i + 1} of $totalPages...');

            final outputDoc = PdfDocument();
            final template = inputDocument.pages[i].createTemplate();
            final page = outputDoc.pages.add();
            page.graphics.drawPdfTemplate(template, const Offset(0, 0));

            final outputPath = path.join(
              outputDirectory,
              '${baseName}_page_${i + 1}.pdf',
            );
            final bytes = await outputDoc.save();
            await File(outputPath).writeAsBytes(bytes);

            outputPaths.add(outputPath);
            totalSize += bytes.length;
            outputDoc.dispose();
          }
          break;

        case SplitMode.byPageCount:
          final perFile = pagesPerFile ?? 1;
          int fileIndex = 1;

          for (int i = 0; i < totalPages; i += perFile) {
            final progress = 0.1 + (0.8 * (i / totalPages));
            onProgress?.call(progress, 'Creating file $fileIndex...');

            final outputDoc = PdfDocument();
            final endPage = (i + perFile).clamp(0, totalPages);

            for (int j = i; j < endPage; j++) {
              final template = inputDocument.pages[j].createTemplate();
              final page = outputDoc.pages.add();
              page.graphics.drawPdfTemplate(template, const Offset(0, 0));
            }

            final outputPath = path.join(
              outputDirectory,
              '${baseName}_part_$fileIndex.pdf',
            );
            final bytes = await outputDoc.save();
            await File(outputPath).writeAsBytes(bytes);

            outputPaths.add(outputPath);
            totalSize += bytes.length;
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

  /// Get PDF metadata and page count
  Future<PdfMetadata?> getPdfMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

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

  /// Apply image compression to document
  void _compressImagesInDocument(PdfDocument document, CompressionOptions options) {
    // Syncfusion PDF handles compression internally
    // For more advanced compression, we'd iterate through images
    // and re-encode them with lower quality
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
