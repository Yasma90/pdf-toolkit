# PDF Toolkit

A powerful, cross-platform PDF manipulation application built with Flutter for Windows and Android.

## Features

### Compress PDF

Reduce PDF file size with multiple compression levels:

| Level | Quality | Expected Reduction | Best For |
|-------|---------|-------------------|----------|
| Low | 95% | 10-20% | Professional printing |
| Medium | 75% | 30-50% | General use, email |
| High | 50% | 50-70% | Web uploads, archiving |
| Extreme | 30% | 70-90% | Quick previews |

**Advanced Options:**

- Compress images within PDF
- Remove metadata (author, title, etc.)
- Remove annotations and comments
- Optimize for web (linearization)

### Merge PDFs

Combine multiple PDF files into a single document:

- Select multiple PDF files
- Drag-and-drop to reorder files
- Visual list with file sizes
- Progress indicator during merge

### Split PDF

Divide a PDF into multiple files:

- **Every Page**: Create one PDF per page
- **By Page Count**: Specify number of pages per file
- Automatic file naming

### Convert to Images

Export PDF pages as images:

| Quality | DPI | Use Case |
|---------|-----|----------|
| Low | 72 | Fast preview, small files |
| Medium | 150 | Balanced quality |
| High | 300 | High quality output |
| Print | 600 | Professional printing |

**Supported Formats:**

- PNG (lossless, transparency support)
- JPEG (smaller files)
- WebP (modern, best compression)

### Protect PDF

Add password protection and permissions:

**Encryption Levels:**

- RC4 40-bit (legacy compatibility)
- RC4 128-bit (good compatibility)
- AES 128-bit (strong security)
- AES 256-bit (maximum security - recommended)

**Permission Presets:**

- Full Access: All operations allowed
- No Modifications: Print and copy only
- View Only: No print, copy, or modify
- Custom: Configure individual permissions

**Granular Permissions:**

- Printing (standard/high quality)
- Content modification
- Content copying
- Annotations
- Form filling
- Document assembly
- Accessibility access

### Extract Pages

Extract specific pages from a PDF:

- **Select Pages**: Choose individual pages visually
- **Page Range**: Enter range (e.g., 1-5)
- **Odd Pages**: Extract pages 1, 3, 5...
- **Even Pages**: Extract pages 2, 4, 6...

### Watermark

Add text or image watermarks to your PDFs:

**Position Options:**

| Position          | Description                   |
| ----------------- | ----------------------------- |
| Top/Center/Bottom | Standard 9-position grid      |
| Diagonal          | Centered with rotation        |
| Tile              | Repeating pattern across page |

**Customization:**

- Custom text input
- Adjustable opacity (10-100%)
- Font size (12-120pt)
- Rotation angle (-90° to 90°)
- Color picker with 10 preset colors
- Apply to all pages or specific pages

### Rotate Pages

Rotate PDF pages with precision:

**Rotation Angles:**

- 90° Clockwise (→)
- 180° (full rotation)
- 90° Counter-clockwise (←)

**Page Selection:**

- Rotate all pages
- Specify individual pages (e.g., 1, 3, 5-10)
- Support for page ranges

### Add Page Numbers

Professional page numbering with multiple formats:

**Number Formats:**

| Format      | Example      |
| ----------- | ------------ |
| Simple      | 1, 2, 3      |
| With Total  | 1 / 10       |
| Page X      | Page 1       |
| Page X of Y | Page 1 of 10 |
| Roman       | I, II, III   |
| Letter      | A, B, C      |

**Customization:**

- 6 position options (corners and centers)
- Custom start number
- Prefix and suffix text
- Font size adjustment
- Skip first page (for covers)
- Live preview of format

### Unlock PDF

Remove password protection from PDFs:

- Enter existing password to unlock
- Removes both user and owner passwords
- Visual locked/unlocked indicator
- Secure password input with visibility toggle

### Reorder & Delete Pages

Reorganize your PDF structure:

**Features:**

- Drag-and-drop page reordering
- Visual page list with thumbnails
- Mark pages for deletion
- Real-time position tracking
- Restore accidentally marked pages
- Apply changes with confirmation

### Batch Processing

Process multiple PDFs simultaneously:

**Supported Operations:**

- Compress multiple files
- Add watermark to multiple PDFs
- Rotate pages in batch
- Add page numbers to all files

**Features:**

- Add multiple files at once
- Visual progress for each file
- Success/failure tracking per file
- Stop on error option
- Detailed results summary
- Concurrent processing (configurable)

### Settings

Customize app behavior and preferences:

**Appearance:**

- Theme selection: System / Light / Dark
- Smooth theme transitions

**Output Configuration:**

- Custom output folder selection
- Auto-open files after processing
- Default compression level
- Default image format

**Data Management:**

- Clear recent files history
- Persistent settings across sessions

### Recent Files

Track your processed files:

- Last 20 files with operation history
- Quick access from home screen
- File size and processing time
- Operation type indicator with color coding
- Relative timestamps ("5m ago", "2h ago")

## Tech Stack

| Technology | Purpose |
|------------|---------|
| Flutter 3.x | Cross-platform UI framework |
| Dart 3.x | Programming language |
| Riverpod | State management |
| Syncfusion Flutter PDF | PDF processing |
| Printing | PDF rasterization |
| Material Design 3 | UI design system |

## Project Structure

```text
lib/
├── core/
│   ├── models/
│   │   ├── pdf_file.dart           # PDF file model
│   │   ├── compression_level.dart  # Compression options
│   │   ├── image_format.dart       # Image conversion options
│   │   ├── security_options.dart   # Password & permissions
│   │   ├── extraction_options.dart # Page extraction options
│   │   ├── batch_options.dart      # Batch processing & advanced options
│   │   └── operation_result.dart   # Result types (sealed classes)
│   ├── providers/
│   │   ├── recent_files_provider.dart  # Recent files state
│   │   └── settings_provider.dart      # App settings state
│   └── services/
│       ├── pdf_service.dart        # Core PDF operations
│       ├── pdf_processor.dart      # Advanced PDF processing
│       └── file_service.dart       # File I/O operations
├── features/
│   ├── home/                       # Main dashboard with tool grid
│   ├── compress/                   # PDF compression
│   ├── merge/                      # PDF merging
│   ├── split/                      # PDF splitting
│   ├── convert/                    # PDF to image
│   ├── protect/                    # Password protection
│   ├── extract/                    # Page extraction
│   ├── watermark/                  # Add watermarks
│   ├── rotate/                     # Rotate pages
│   ├── pagenumbers/                # Add page numbers
│   ├── unlock/                     # Remove passwords
│   ├── reorder/                    # Reorder & delete pages
│   ├── batch/                      # Batch processing
│   └── settings/                   # App settings
└── shared/
    ├── theme/
    │   └── app_theme.dart          # Material 3 theming
    └── widgets/
        ├── tool_card.dart          # Home screen cards
        ├── file_drop_zone.dart     # File picker widget
        └── progress_card.dart      # Progress & results
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2.0 or higher
- Dart SDK 3.2.0 or higher
- Android Studio / VS Code with Flutter extensions
- For Windows: Visual Studio 2022 with C++ desktop development
- For Android: Android SDK with API level 21+

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/pdf-toolkit.git
cd pdf-toolkit
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
# For Android
flutter run -d android

# For Windows
flutter run -d windows
```

### Building for Production

#### Using Build Scripts (Recommended)

**Windows (PowerShell):**

```powershell
# Build both Android and Windows
.\scripts\build.ps1 -target all

# Build only Android APK
.\scripts\build.ps1 -target android

# Build only Windows executable
.\scripts\build.ps1 -target windows
```

**Linux/macOS (Bash):**

```bash
# Build both platforms
./scripts/build.sh all

# Build only Android
./scripts/build.sh android
```

#### Manual Build Commands

```bash
# Android APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# Windows Executable
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

### Build Output Locations

| Platform | Build Type | Output Path |
|----------|------------|-------------|
| Android | APK | `build/app/outputs/flutter-apk/app-release.apk` |
| Android | AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Windows | EXE | `build/windows/x64/runner/Release/pdf_toolkit.exe` |

## Architecture

This project follows **Clean Architecture** principles with a **Feature-First** structure:

### Layers

```text
┌─────────────────────────────────────┐
│           Presentation              │  Screens, Widgets
├─────────────────────────────────────┤
│           State Management          │  Riverpod Providers
├─────────────────────────────────────┤
│           Business Logic            │  Services
├─────────────────────────────────────┤
│           Data Models               │  Immutable classes
└─────────────────────────────────────┘
```

### Key Patterns

- **Sealed Classes**: Type-safe operation results
- **Riverpod**: Dependency injection and reactive state
- **Immutable Models**: `copyWith` pattern for state updates
- **Service Layer**: Business logic separated from UI
- **Persistent Storage**: JSON-based settings and history

## Git Flow

This project follows Git Flow branching strategy:

```text
master ────────────────────────────────────────
  │
  └─> develop ──┬── feature/compress
                ├── feature/merge
                ├── feature/split
                ├── feature/convert-to-image
                ├── feature/password-protection
                ├── feature/extract-pages
                ├── feature/ux-improvements
                └── feature/advanced-tools (watermark, rotate, etc.)
```

### Branches

| Branch | Purpose |
| ------ | ------- |
| `master` | Production releases |
| `develop` | Integration branch |
| `feature/*` | New features |
| `hotfix/*` | Production fixes |
| `release/*` | Release preparation |

### Feature Development Workflow

1. Create feature branch from `develop`
2. Implement feature with tests
3. **Document feature in README**
4. Commit with conventional commits
5. Merge to `develop` with `--no-ff`
6. Delete feature branch

## Design System

### Colors

**Essential Tools:**

| Tool     | Color | Hex       |
| -------- | ----- | --------- |
| Compress | Green | `#10B981` |
| Merge    | Blue  | `#3B82F6` |
| Split    | Amber | `#F59E0B` |
| Convert  | Pink  | `#EC4899` |

**Page Tools:**

| Tool     | Color  | Hex       |
| -------- | ------ | --------- |
| Extract  | Teal   | `#14B8A6` |
| Rotate   | Orange | `#F97316` |
| Reorder  | Indigo | `#6366F1` |
| Numbers  | Lime   | `#84CC16` |

**Security & Enhancement:**

| Tool      | Color     | Hex       |
| --------- | --------- | --------- |
| Protect   | Purple    | `#8B5CF6` |
| Unlock    | Red       | `#EF4444` |
| Watermark | Sky Blue  | `#0EA5E9` |
| Batch     | Violet    | `#A855F7` |

### Theme Support

- Light mode (default)
- Dark mode (system preference or manual)
- Material Design 3 components
- Responsive layouts (mobile/desktop)
- Persistent theme preference

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.4.9      # State management
  syncfusion_flutter_pdf: ^24.1.41  # PDF processing
  printing: ^5.11.1             # PDF rasterization
  file_picker: ^6.1.1           # File selection
  path_provider: ^2.1.2         # File paths
  share_plus: ^7.2.1            # File sharing
  google_fonts: ^6.1.0          # Typography
  percent_indicator: ^4.2.3     # Progress UI
```

## Data Storage

The app stores data locally in JSON format:

| File | Location | Purpose |
|------|----------|---------|
| `settings.json` | Documents/PDF Toolkit/ | App preferences |
| `recent_files.json` | Documents/PDF Toolkit/ | Processing history |

## Contributing

1. Fork the repository

2. Create your feature branch:

   ```bash
   git checkout develop
   git checkout -b feature/amazing-feature
   ```

3. Implement and **document** your feature

4. Commit your changes:

   ```bash
   git commit -m 'feat: add amazing feature'
   ```

5. Push to the branch:

   ```bash
   git push origin feature/amazing-feature
   ```

6. Open a Pull Request to `develop`

### Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Purpose |
|--------|---------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `style:` | Formatting |
| `refactor:` | Code restructuring |
| `test:` | Tests |
| `chore:` | Maintenance |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Syncfusion Flutter PDF](https://pub.dev/packages/syncfusion_flutter_pdf) - PDF processing
- [Flutter Riverpod](https://riverpod.dev/) - State management
- [Google Fonts](https://fonts.google.com/) - Typography
- [Heroicons](https://heroicons.com/) - Icon inspiration
