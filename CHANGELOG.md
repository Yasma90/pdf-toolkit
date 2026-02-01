# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-01-31

### Added

- **PDF Compression now works on Android** - integrated pdf_compressor package with iText library
  - Uses local fork with AGP 8+ compatibility fix (added `namespace` declaration)
  - Compression levels mapped: Low (50%), Medium (30%), High/Extreme (10% quality)
  - Falls back to Syncfusion if native compression fails

### Fixed

- Fixed pdf_compressor AGP 8+ build error by adding `namespace 'com.kaizen404.pdf_compressor'`
- Updated pdf_compressor build.gradle: compileSdkVersion 34, minSdkVersion 21, replaced jcenter with mavenCentral

### Changed

- Compress feature now enabled on both Windows (Ghostscript) and Android (iText/pdf_compressor)
- Removed "Windows only" badge from Compress tool on home screen

## [1.0.1] - 2026-01-31

### Fixed

- **PDF Merge/Split/Extract now preserves page dimensions** - fixed issue where merged PDFs lost original page margins and sizes by using sections with `pageSettings.size` to match source page dimensions
- **PDF Compression now works correctly** - files are actually reduced in size
  - **Windows**: Uses Ghostscript for professional-grade compression (30-90% reduction)
    - Low: 200 DPI, 85% JPEG quality (high-quality printing)
    - Medium: 150 DPI, 70% JPEG quality (general use)
    - High: 100 DPI, 50% JPEG quality (web quality)
    - Extreme: 72 DPI, 30% JPEG quality (maximum compression)
  - **Android/iOS**: Uses Syncfusion structure optimization (limited image compression)
- Resolved PdfDocument import conflict between `pdf` and `syncfusion_flutter_pdf` packages
- Fixed AnimatedBuilder widget parameter mismatch (changed `animation` to `listenable`)
- Corrected RecentFilesNotifier method calls (changed `addFile` to `addEntry`)
- Fixed PdfFile property access (changed `fileSize` to `sizeInBytes`)
- Fixed FileDropZone and pickPdfFiles parameter names (changed `allowMultiple` to `multiple`)
- Added missing OperationResult import in batch_screen.dart
- **Drag & drop now works on Windows** - added `desktop_drop` package support

### Added

- **Save button** in all result screens (Merge, Split, Extract, Rotate, Reorder, Compress, Convert, Protect, Unlock, Watermark, Page Numbers)
- **WINDOWS_REQUIREMENTS.md** - documentation for Ghostscript installation

### Changed

- Updated Android compileSdk from 34 to 35 (required by flutter_plugin_android_lifecycle)
- Updated Android NDK version to 25.1.8937393 (required by multiple plugins)
- Refactored PdfService compression methods for better maintainability
- Updated compression level mapping to use Dart 3 switch expressions
- Improved Ghostscript compression parameters for better file size reduction
  - Added JPEG quality control per compression level
  - Enabled duplicate image detection
  - Enabled font compression and optimization flags

## [1.0.0] - 2026-01-30

### Added

#### Essential Tools
- **Compress PDF**: Reduce file size with 4 compression levels (Low, Medium, High, Extreme)
  - Advanced options: compress images, remove metadata, remove annotations, optimize for web
- **Merge PDF**: Combine multiple PDF files into a single document
  - Drag-and-drop file reordering
  - Visual file list with sizes
- **Split PDF**: Divide PDF into multiple files
  - Split every page or by page count
  - Automatic file naming
- **Convert to Images**: Export PDF pages as PNG, JPEG, or WebP
  - Quality presets: 72, 150, 300, 600 DPI

#### Page Tools
- **Extract Pages**: Extract specific pages from PDF
  - Select individual pages, ranges, odd/even pages
- **Rotate Pages**: Rotate pages 90°, 180°, or 270°
  - Apply to all pages or specific pages
- **Reorder & Delete Pages**: Reorganize PDF structure
  - Drag-and-drop page reordering
  - Mark pages for deletion with restore option
- **Add Page Numbers**: Professional page numbering
  - 6 formats: Simple, With Total, Page X, Page X of Y, Roman, Letter
  - 6 position options, custom prefix/suffix, skip first page

#### Security & Enhancement
- **Protect PDF**: Add password protection and permissions
  - Encryption: RC4 40/128-bit, AES 128/256-bit
  - Permission presets: Full Access, No Modifications, View Only, Custom
- **Unlock PDF**: Remove password protection from PDFs
  - Secure password input with visibility toggle
- **Watermark**: Add text watermarks to PDFs
  - 9 positions + diagonal + tile modes
  - Adjustable opacity, font size, rotation, color
- **Batch Processing**: Process multiple PDFs simultaneously
  - Supported operations: Compress, Watermark, Rotate, Page Numbers
  - Visual progress tracking per file

#### User Experience
- **Settings Screen**: Customize app behavior
  - Theme selection: System, Light, Dark
  - Custom output folder selection
  - Default compression level and image format
- **Recent Files**: Track processed files
  - Last 20 files with operation history
  - Quick access from home screen
- **Responsive Design**: Optimized for mobile and desktop
- **Material Design 3**: Modern UI with light/dark themes

### Technical
- Flutter 3.x with Dart 3.x
- Riverpod for state management
- Syncfusion Flutter PDF for PDF processing
- Clean Architecture with Feature-First structure
- Sealed classes for type-safe operation results
- JSON-based persistent storage for settings and history

## [0.1.0] - 2026-01-29

### Added
- Initial project setup
- Basic project structure with Clean Architecture
- Core models: PdfFile, CompressionLevel, OperationResult
- Basic services: PdfService, FileService
- Material Design 3 theme system

[Unreleased]: https://github.com/user/pdf-toolkit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/user/pdf-toolkit/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/user/pdf-toolkit/releases/tag/v0.1.0
