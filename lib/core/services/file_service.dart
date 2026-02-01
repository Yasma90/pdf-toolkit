import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:pdf_toolkit/core/models/pdf_file.dart';

/// Service for file operations
class FileService {
  /// Pick one or more PDF files
  Future<List<PdfFile>> pickPdfFiles({bool multiple = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: multiple,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final pdfFiles = <PdfFile>[];
    for (final file in result.files) {
      if (file.path != null) {
        final pdfFile = await PdfFile.fromFile(File(file.path!));
        pdfFiles.add(pdfFile);
      }
    }

    return pdfFiles;
  }

  /// Pick a directory for output
  Future<String?> pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    return result;
  }

  /// Get the default output directory
  Future<String> getDefaultOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDir = Directory(path.join(directory.path, 'PDF Toolkit'));

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir.path;
  }

  /// Generate output file path
  Future<String> generateOutputPath({
    required String inputPath,
    required String suffix,
    String? outputDirectory,
  }) async {
    final dir = outputDirectory ?? await getDefaultOutputDirectory();
    final baseName = path.basenameWithoutExtension(inputPath);
    final extension = path.extension(inputPath);

    String outputPath = path.join(dir, '$baseName$suffix$extension');

    // Ensure unique filename
    int counter = 1;
    while (await File(outputPath).exists()) {
      outputPath = path.join(dir, '$baseName$suffix ($counter)$extension');
      counter++;
    }

    return outputPath;
  }

  /// Share a file
  Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  /// Share multiple files
  Future<void> shareFiles(List<String> filePaths) async {
    final xFiles = filePaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xFiles);
  }

  /// Delete a file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final stat = await file.stat();
      return stat.size;
    }
    return 0;
  }

  /// Copy file to a new location
  Future<String?> copyFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        final newFile = await sourceFile.copy(destinationPath);
        return newFile.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save file to user-selected location (Save As dialog)
  Future<String?> saveFileAs(String sourcePath, {String? suggestedName}) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final fileName = suggestedName ?? path.basename(sourcePath);

      // Use file picker's save dialog
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) return null;

      // Ensure the path has .pdf extension
      String savePath = result;
      if (!savePath.toLowerCase().endsWith('.pdf')) {
        savePath = '$savePath.pdf';
      }

      // Copy file to selected location
      await sourceFile.copy(savePath);
      return savePath;
    } catch (e) {
      return null;
    }
  }

  /// Get recent files from output directory
  Future<List<PdfFile>> getRecentFiles({int limit = 10}) async {
    try {
      final outputDir = await getDefaultOutputDirectory();
      final directory = Directory(outputDir);

      if (!await directory.exists()) {
        return [];
      }

      final files = await directory
          .list()
          .where((entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.pdf'))
          .cast<File>()
          .toList();

      // Sort by modification date
      files.sort((a, b) {
        final aDate = a.statSync().modified;
        final bDate = b.statSync().modified;
        return bDate.compareTo(aDate);
      });

      final pdfFiles = <PdfFile>[];
      for (final file in files.take(limit)) {
        pdfFiles.add(await PdfFile.fromFile(file));
      }

      return pdfFiles;
    } catch (e) {
      return [];
    }
  }
}
