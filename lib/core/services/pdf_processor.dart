import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_toolkit/core/models/batch_options.dart';
import 'package:pdf_toolkit/core/models/operation_result.dart';

/// Unified PDF processor with optimized algorithms
class PdfProcessor {
  /// Process queue for batch operations
  final _processingQueue = <Future<void>>[];

  /// Add watermark to PDF
  Future<OperationResult<String>> addWatermark({
    required String inputPath,
    required String outputPath,
    required WatermarkOptions options,
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
      final document = PdfDocument(inputBytes: inputBytes);
      final pageCount = document.pages.count;

      onProgress?.call(0.2, 'Applying watermark...');

      // Determine which pages to watermark
      final pagesToProcess = options.allPages
          ? List.generate(pageCount, (i) => i)
          : (options.specificPages ?? List.generate(pageCount, (i) => i));

      for (int i = 0; i < pagesToProcess.length; i++) {
        final pageIndex = pagesToProcess[i];
        if (pageIndex >= pageCount) continue;

        final progress = 0.2 + (0.6 * (i / pagesToProcess.length));
        onProgress?.call(progress, 'Watermarking page ${pageIndex + 1}...');

        final page = document.pages[pageIndex];
        final graphics = page.graphics;
        final pageSize = page.size;

        // Save graphics state
        graphics.save();

        // Set transparency
        graphics.setTransparency(options.opacity);

        if (options.type == WatermarkType.text) {
          _drawTextWatermark(graphics, pageSize, options);
        }

        // Restore graphics state
        graphics.restore();
      }

      onProgress?.call(0.9, 'Saving...');

      final outputBytes = await document.save();
      document.dispose();

      await File(outputPath).writeAsBytes(outputBytes);

      stopwatch.stop();

      return OperationSuccess(
        data: outputPath,
        message: 'Watermark added successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to add watermark',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  void _drawTextWatermark(
    PdfGraphics graphics,
    Size pageSize,
    WatermarkOptions options,
  ) {
    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      options.fontSize,
      style: PdfFontStyle.bold,
    );

    final color = _parseColor(options.fontColor);
    final brush = PdfSolidBrush(color);

    final textSize = font.measureString(options.text);

    // Calculate position based on option
    Offset position;
    switch (options.position) {
      case WatermarkPosition.topLeft:
        position = const Offset(20, 20);
        break;
      case WatermarkPosition.topCenter:
        position = Offset((pageSize.width - textSize.width) / 2, 20);
        break;
      case WatermarkPosition.topRight:
        position = Offset(pageSize.width - textSize.width - 20, 20);
        break;
      case WatermarkPosition.centerLeft:
        position = Offset(20, (pageSize.height - textSize.height) / 2);
        break;
      case WatermarkPosition.center:
      case WatermarkPosition.diagonal:
        position = Offset(
          (pageSize.width - textSize.width) / 2,
          (pageSize.height - textSize.height) / 2,
        );
        break;
      case WatermarkPosition.centerRight:
        position = Offset(
          pageSize.width - textSize.width - 20,
          (pageSize.height - textSize.height) / 2,
        );
        break;
      case WatermarkPosition.bottomLeft:
        position = Offset(20, pageSize.height - textSize.height - 20);
        break;
      case WatermarkPosition.bottomCenter:
        position = Offset(
          (pageSize.width - textSize.width) / 2,
          pageSize.height - textSize.height - 20,
        );
        break;
      case WatermarkPosition.bottomRight:
        position = Offset(
          pageSize.width - textSize.width - 20,
          pageSize.height - textSize.height - 20,
        );
        break;
      case WatermarkPosition.tile:
        // Draw tiled watermark
        _drawTiledWatermark(graphics, pageSize, options, font, brush);
        return;
    }

    // Apply rotation if diagonal
    if (options.position == WatermarkPosition.diagonal ||
        options.rotation != 0) {
      graphics.save();
      graphics.translateTransform(
        pageSize.width / 2,
        pageSize.height / 2,
      );
      graphics.rotateTransform(options.rotation);
      graphics.translateTransform(
        -pageSize.width / 2,
        -pageSize.height / 2,
      );
    }

    graphics.drawString(
      options.text,
      font,
      brush: brush,
      bounds: Rect.fromLTWH(position.dx, position.dy, 0, 0),
    );

    if (options.position == WatermarkPosition.diagonal ||
        options.rotation != 0) {
      graphics.restore();
    }
  }

  void _drawTiledWatermark(
    PdfGraphics graphics,
    Size pageSize,
    WatermarkOptions options,
    PdfFont font,
    PdfBrush brush,
  ) {
    final textSize = font.measureString(options.text);
    final spacingX = textSize.width + 50;
    final spacingY = textSize.height + 50;

    for (double y = 0; y < pageSize.height; y += spacingY) {
      for (double x = 0; x < pageSize.width; x += spacingX) {
        graphics.save();
        graphics.translateTransform(x + textSize.width / 2, y + textSize.height / 2);
        graphics.rotateTransform(options.rotation);
        graphics.translateTransform(-textSize.width / 2, -textSize.height / 2);
        graphics.drawString(options.text, font, brush: brush);
        graphics.restore();
      }
    }
  }

  /// Rotate PDF pages
  Future<OperationResult<String>> rotatePages({
    required String inputPath,
    required String outputPath,
    required RotateOptions options,
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
      final document = PdfDocument(inputBytes: inputBytes);
      final pageCount = document.pages.count;

      onProgress?.call(0.2, 'Rotating pages...');

      final pagesToRotate = options.allPages
          ? List.generate(pageCount, (i) => i)
          : (options.specificPages ?? []);

      for (int i = 0; i < pagesToRotate.length; i++) {
        final pageIndex = pagesToRotate[i];
        if (pageIndex >= pageCount) continue;

        final progress = 0.2 + (0.6 * (i / pagesToRotate.length));
        onProgress?.call(progress, 'Rotating page ${pageIndex + 1}...');

        final page = document.pages[pageIndex];

        // Apply rotation
        final currentRotation = page.rotation.index * 90;
        final newRotation = (currentRotation + options.angle.degrees) % 360;

        page.rotation = PdfPageRotateAngle.values[newRotation ~/ 90];
      }

      onProgress?.call(0.9, 'Saving...');

      final outputBytes = await document.save();
      document.dispose();

      await File(outputPath).writeAsBytes(outputBytes);

      stopwatch.stop();

      return OperationSuccess(
        data: outputPath,
        message: 'Pages rotated successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to rotate pages',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Add page numbers to PDF
  Future<OperationResult<String>> addPageNumbers({
    required String inputPath,
    required String outputPath,
    required PageNumberOptions options,
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
      final document = PdfDocument(inputBytes: inputBytes);
      final pageCount = document.pages.count;

      onProgress?.call(0.2, 'Adding page numbers...');

      final excludeSet = (options.excludePages ?? []).toSet();

      for (int i = 0; i < pageCount; i++) {
        if (options.skipFirstPage && i == 0) continue;
        if (excludeSet.contains(i)) continue;

        final progress = 0.2 + (0.6 * (i / pageCount));
        onProgress?.call(progress, 'Numbering page ${i + 1}...');

        final page = document.pages[i];
        final graphics = page.graphics;
        final pageSize = page.size;

        final font = PdfStandardFont(PdfFontFamily.helvetica, options.fontSize);
        final color = _parseColor(options.fontColor);
        final brush = PdfSolidBrush(color);

        final text = options.formatPageNumber(i + 1, pageCount);
        final textSize = font.measureString(text);

        // Calculate position
        Offset position;
        const margin = 30.0;

        switch (options.position) {
          case PageNumberPosition.topLeft:
            position = const Offset(margin, margin);
            break;
          case PageNumberPosition.topCenter:
            position = Offset((pageSize.width - textSize.width) / 2, margin);
            break;
          case PageNumberPosition.topRight:
            position = Offset(pageSize.width - textSize.width - margin, margin);
            break;
          case PageNumberPosition.bottomLeft:
            position = Offset(margin, pageSize.height - margin - textSize.height);
            break;
          case PageNumberPosition.bottomCenter:
            position = Offset(
              (pageSize.width - textSize.width) / 2,
              pageSize.height - margin - textSize.height,
            );
            break;
          case PageNumberPosition.bottomRight:
            position = Offset(
              pageSize.width - textSize.width - margin,
              pageSize.height - margin - textSize.height,
            );
            break;
        }

        graphics.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(position.dx, position.dy, 0, 0),
        );
      }

      onProgress?.call(0.9, 'Saving...');

      final outputBytes = await document.save();
      document.dispose();

      await File(outputPath).writeAsBytes(outputBytes);

      stopwatch.stop();

      return OperationSuccess(
        data: outputPath,
        message: 'Page numbers added successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to add page numbers',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Unlock password-protected PDF
  Future<OperationResult<String>> unlockPdf({
    required String inputPath,
    required String outputPath,
    required String password,
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

      onProgress?.call(0.3, 'Unlocking PDF...');

      // Load with password
      final document = PdfDocument(inputBytes: inputBytes, password: password);

      onProgress?.call(0.5, 'Removing security...');

      // Remove security
      document.security.userPassword = '';
      document.security.ownerPassword = '';

      onProgress?.call(0.8, 'Saving...');

      final outputBytes = await document.save();
      document.dispose();

      await File(outputPath).writeAsBytes(outputBytes);

      stopwatch.stop();

      return OperationSuccess(
        data: outputPath,
        message: 'PDF unlocked successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      if (e.toString().contains('password')) {
        return const OperationFailure(
          error: 'Invalid password',
          details: 'The password provided is incorrect',
        );
      }
      return OperationFailure(
        error: 'Failed to unlock PDF',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Reorder pages in PDF
  Future<OperationResult<String>> reorderPages({
    required String inputPath,
    required String outputPath,
    required List<int> newOrder,
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
      final pageCount = inputDocument.pages.count;

      // Validate order
      if (newOrder.length != pageCount) {
        return const OperationFailure(
          error: 'Invalid page order',
          details: 'New order must contain all pages',
        );
      }

      onProgress?.call(0.2, 'Reordering pages...');

      // Create new document with reordered pages
      final outputDocument = PdfDocument();

      for (int i = 0; i < newOrder.length; i++) {
        final pageIndex = newOrder[i];
        if (pageIndex < 0 || pageIndex >= pageCount) {
          return OperationFailure(
            error: 'Invalid page index: $pageIndex',
          );
        }

        final progress = 0.2 + (0.6 * (i / newOrder.length));
        onProgress?.call(progress, 'Processing page ${i + 1}...');

        final template = inputDocument.pages[pageIndex].createTemplate();
        final page = outputDocument.pages.add();
        page.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      inputDocument.dispose();

      onProgress?.call(0.9, 'Saving...');

      final outputBytes = await outputDocument.save();
      outputDocument.dispose();

      await File(outputPath).writeAsBytes(outputBytes);

      stopwatch.stop();

      return OperationSuccess(
        data: outputPath,
        message: 'Pages reordered successfully',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to reorder pages',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete specific pages from PDF
  Future<OperationResult<String>> deletePages({
    required String inputPath,
    required String outputPath,
    required List<int> pagesToDelete,
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
      final pageCount = inputDocument.pages.count;

      final deleteSet = pagesToDelete.toSet();
      final pagesToKeep = List.generate(pageCount, (i) => i)
          .where((i) => !deleteSet.contains(i))
          .toList();

      if (pagesToKeep.isEmpty) {
        return const OperationFailure(
          error: 'Cannot delete all pages',
        );
      }

      onProgress?.call(0.2, 'Removing pages...');

      final outputDocument = PdfDocument();

      for (int i = 0; i < pagesToKeep.length; i++) {
        final pageIndex = pagesToKeep[i];
        final progress = 0.2 + (0.6 * (i / pagesToKeep.length));
        onProgress?.call(progress, 'Processing page ${i + 1}...');

        final template = inputDocument.pages[pageIndex].createTemplate();
        final page = outputDocument.pages.add();
        page.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      inputDocument.dispose();

      onProgress?.call(0.9, 'Saving...');

      final outputBytes = await outputDocument.save();
      outputDocument.dispose();

      await File(outputPath).writeAsBytes(outputBytes);

      stopwatch.stop();

      return OperationSuccess(
        data: outputPath,
        message: '${pagesToDelete.length} pages deleted',
        duration: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return OperationFailure(
        error: 'Failed to delete pages',
        details: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }

  /// Parse hex color string to PdfColor
  PdfColor _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return PdfColor(r, g, b);
    }
    return PdfColor(128, 128, 128); // Default gray
  }
}
