# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-01-31

### Fixed

- **PDF Compression now works correctly** - files are actually reduced in size
  - Disabled incremental updates to force full document rewrite
  - Enabled cross-reference streams for more efficient PDF structure
  - Properly applies compression level to content streams
  - **Image compression now functional** - embedded images are recompressed based on level:
    - Low: 90% quality, max 4096px
    - Medium: 70% quality, max 2048px
    - High: 50% quality, max 1600px
    - Extreme: 30% quality, max 1200px
- Resolved PdfDocument import conflict between `pdf` and `syncfusion_flutter_pdf` packages
- Fixed AnimatedBuilder widget parameter mismatch (changed `animation` to `listenable`)
- Corrected RecentFilesNotifier method calls (changed `addFile` to `addEntry`)
- Fixed PdfFile property access (changed `fileSize` to `sizeInBytes`)
- Fixed FileDropZone and pickPdfFiles parameter names (changed `allowMultiple` to `multiple`)
- Added missing OperationResult import in batch_screen.dart
- **Drag & drop now works on Windows** - added `desktop_drop` package support

### Changed

- Updated Android compileSdk from 34 to 35 (required by flutter_plugin_android_lifecycle)
- Updated Android NDK version to 25.1.8937393 (required by multiple plugins)
- Refactored PdfService compression methods for better maintainability
- Updated compression level mapping to use Dart 3 switch expressions

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
