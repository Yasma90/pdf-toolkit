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

```
lib/
├── core/
│   ├── models/
│   │   ├── pdf_file.dart           # PDF file model
│   │   ├── compression_level.dart  # Compression options
│   │   ├── image_format.dart       # Image conversion options
│   │   ├── security_options.dart   # Password & permissions
│   │   ├── extraction_options.dart # Page extraction options
│   │   └── operation_result.dart   # Result types
│   └── services/
│       ├── pdf_service.dart        # PDF operations
│       └── file_service.dart       # File I/O operations
├── features/
│   ├── home/                       # Main dashboard
│   ├── compress/                   # PDF compression
│   ├── merge/                      # PDF merging
│   ├── split/                      # PDF splitting
│   ├── convert/                    # PDF to image
│   ├── protect/                    # Password protection
│   └── extract/                    # Page extraction
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

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# Windows MSIX
flutter build windows --release
```

## Architecture

This project follows **Clean Architecture** principles with a **Feature-First** structure:

### Layers

```
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

## Git Flow

This project follows Git Flow branching strategy:

```
main ──────────────────────────────────────
  │
  └─> develop ──┬── feature/compress
                ├── feature/merge
                ├── feature/split
                ├── feature/convert-to-image
                ├── feature/password-protection
                └── feature/extract-pages
```

### Branches

| Branch | Purpose |
|--------|---------|
| `main` | Production releases |
| `develop` | Integration branch |
| `feature/*` | New features |
| `hotfix/*` | Production fixes |
| `release/*` | Release preparation |

## Design System

### Colors

| Tool | Color | Hex |
|------|-------|-----|
| Compress | Green | `#10B981` |
| Merge | Blue | `#3B82F6` |
| Split | Amber | `#F59E0B` |
| Convert | Pink | `#EC4899` |
| Protect | Purple | `#8B5CF6` |
| Extract | Teal | `#14B8A6` |

### Theme Support

- Light mode (default)
- Dark mode (system preference)
- Material Design 3 components
- Responsive layouts (mobile/desktop)

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

## Contributing

1. Fork the repository
2. Create your feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. Commit your changes:
   ```bash
   git commit -m 'feat: add amazing feature'
   ```
4. Push to the branch:
   ```bash
   git push origin feature/amazing-feature
   ```
5. Open a Pull Request

### Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Formatting
- `refactor:` Code restructuring
- `test:` Tests
- `chore:` Maintenance

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Syncfusion Flutter PDF](https://pub.dev/packages/syncfusion_flutter_pdf) - PDF processing
- [Flutter Riverpod](https://riverpod.dev/) - State management
- [Google Fonts](https://fonts.google.com/) - Typography
- [Heroicons](https://heroicons.com/) - Icon inspiration
