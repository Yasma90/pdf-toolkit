# PDF Toolkit

A powerful, cross-platform PDF manipulation application built with Flutter for Windows and Android.

## Features

### Compress PDF
- Multiple compression levels (Low, Medium, High, Extreme)
- Custom compression settings
- Image optimization
- Metadata removal option
- Web optimization (linearization)

### Merge PDFs
- Combine multiple PDF files into one
- Drag-and-drop reordering
- Visual file list with preview

### Split PDF
- Split by every page
- Split by page count
- Custom page ranges (coming soon)

### Coming Soon
- PDF to Image conversion
- Password protection
- Page extraction
- Watermarking
- OCR text extraction

## Tech Stack

- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **State Management**: Riverpod
- **PDF Processing**: Syncfusion Flutter PDF
- **Architecture**: Feature-first with clean architecture principles

## Project Structure

```
lib/
├── core/
│   ├── models/          # Data models
│   └── services/        # Business logic services
├── features/
│   ├── home/            # Home screen
│   ├── compress/        # PDF compression
│   ├── merge/           # PDF merging
│   └── split/           # PDF splitting
└── shared/
    ├── theme/           # App theme
    ├── utils/           # Utilities
    └── widgets/         # Reusable widgets
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

# Android App Bundle
flutter build appbundle --release

# Windows
flutter build windows --release
```

## Architecture

This project follows clean architecture principles:

- **Models**: Immutable data classes with proper equality
- **Services**: Business logic separated from UI
- **Providers**: Riverpod for dependency injection and state management
- **Widgets**: Reusable, composable UI components
- **Screens**: Feature-specific screens with minimal logic

## Design Principles

- Material Design 3 with custom theming
- Dark mode support
- Responsive layouts for different screen sizes
- Smooth animations and transitions
- Accessibility considerations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Syncfusion Flutter PDF](https://pub.dev/packages/syncfusion_flutter_pdf) for PDF processing
- [Flutter Riverpod](https://riverpod.dev/) for state management
- [Google Fonts](https://fonts.google.com/) for typography
