/// Options for extracting pages from PDF
class ExtractionOptions {
  final ExtractionMode mode;
  final List<int> selectedPages;
  final PageRange? pageRange;
  final bool keepOriginal;

  const ExtractionOptions({
    this.mode = ExtractionMode.selectPages,
    this.selectedPages = const [],
    this.pageRange,
    this.keepOriginal = true,
  });

  ExtractionOptions copyWith({
    ExtractionMode? mode,
    List<int>? selectedPages,
    PageRange? pageRange,
    bool? keepOriginal,
  }) {
    return ExtractionOptions(
      mode: mode ?? this.mode,
      selectedPages: selectedPages ?? this.selectedPages,
      pageRange: pageRange ?? this.pageRange,
      keepOriginal: keepOriginal ?? this.keepOriginal,
    );
  }

  /// Get pages to extract based on mode
  List<int> getEffectivePages(int totalPages) {
    switch (mode) {
      case ExtractionMode.selectPages:
        return selectedPages.where((p) => p >= 0 && p < totalPages).toList();
      case ExtractionMode.pageRange:
        if (pageRange == null) return [];
        final start = pageRange!.start.clamp(0, totalPages - 1);
        final end = pageRange!.end.clamp(0, totalPages - 1);
        return List.generate(end - start + 1, (i) => start + i);
      case ExtractionMode.oddPages:
        return List.generate(totalPages, (i) => i)
            .where((p) => p % 2 == 0)
            .toList();
      case ExtractionMode.evenPages:
        return List.generate(totalPages, (i) => i)
            .where((p) => p % 2 == 1)
            .toList();
    }
  }
}

/// Mode for extracting pages
enum ExtractionMode {
  selectPages(
    name: 'Select Pages',
    description: 'Choose specific pages to extract',
    icon: '📑',
  ),
  pageRange(
    name: 'Page Range',
    description: 'Extract a range of pages (e.g., 1-5)',
    icon: '📊',
  ),
  oddPages(
    name: 'Odd Pages',
    description: 'Extract pages 1, 3, 5, etc.',
    icon: '1️⃣',
  ),
  evenPages(
    name: 'Even Pages',
    description: 'Extract pages 2, 4, 6, etc.',
    icon: '2️⃣',
  );

  const ExtractionMode({
    required this.name,
    required this.description,
    required this.icon,
  });

  final String name;
  final String description;
  final String icon;
}

/// Represents a range of pages
class PageRange {
  final int start;
  final int end;

  const PageRange({
    required this.start,
    required this.end,
  });

  /// Parse from string like "1-5" or "3-10"
  static PageRange? parse(String input) {
    final parts = input.split('-');
    if (parts.length != 2) return null;

    final start = int.tryParse(parts[0].trim());
    final end = int.tryParse(parts[1].trim());

    if (start == null || end == null) return null;
    if (start < 1 || end < start) return null;

    return PageRange(start: start - 1, end: end - 1); // Convert to 0-indexed
  }

  /// Display string (1-indexed for users)
  String get displayString => '${start + 1}-${end + 1}';

  /// Number of pages in range
  int get pageCount => end - start + 1;
}

/// Result of extraction operation
class ExtractionResult {
  final String outputPath;
  final int extractedPages;
  final int outputSize;
  final Duration processingTime;

  const ExtractionResult({
    required this.outputPath,
    required this.extractedPages,
    required this.outputSize,
    required this.processingTime,
  });

  String get formattedSize {
    if (outputSize < 1024) return '$outputSize B';
    if (outputSize < 1024 * 1024) {
      return '${(outputSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(outputSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
