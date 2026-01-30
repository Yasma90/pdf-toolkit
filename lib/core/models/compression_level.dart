/// Compression levels for PDF files
enum CompressionLevel {
  /// Minimal compression - highest quality, largest file size
  /// Best for: Documents that will be printed professionally
  low(
    name: 'Low',
    description: 'Highest quality, minimal size reduction',
    icon: '🔵',
    quality: 95,
    imageQuality: 90,
    expectedReduction: '10-20%',
  ),

  /// Balanced compression - good quality with reasonable size
  /// Best for: General use, sharing via email
  medium(
    name: 'Medium',
    description: 'Balanced quality and compression',
    icon: '🟢',
    quality: 75,
    imageQuality: 70,
    expectedReduction: '30-50%',
  ),

  /// High compression - acceptable quality, significantly smaller
  /// Best for: Web uploads, archiving
  high(
    name: 'High',
    description: 'Good compression, acceptable quality',
    icon: '🟡',
    quality: 50,
    imageQuality: 50,
    expectedReduction: '50-70%',
  ),

  /// Maximum compression - lowest quality, smallest file size
  /// Best for: Quick previews, very limited storage
  extreme(
    name: 'Extreme',
    description: 'Maximum compression, lower quality',
    icon: '🔴',
    quality: 30,
    imageQuality: 30,
    expectedReduction: '70-90%',
  ),

  /// Custom compression - user defined settings
  custom(
    name: 'Custom',
    description: 'Custom compression settings',
    icon: '⚙️',
    quality: 0,
    imageQuality: 0,
    expectedReduction: 'Variable',
  );

  const CompressionLevel({
    required this.name,
    required this.description,
    required this.icon,
    required this.quality,
    required this.imageQuality,
    required this.expectedReduction,
  });

  final String name;
  final String description;
  final String icon;
  final int quality;
  final int imageQuality;
  final String expectedReduction;
}

/// Options for PDF compression
class CompressionOptions {
  final CompressionLevel level;
  final int? customQuality;
  final int? customImageQuality;
  final bool compressImages;
  final bool removeMetadata;
  final bool removeFonts;
  final bool removeAnnotations;
  final bool linearize;

  const CompressionOptions({
    this.level = CompressionLevel.medium,
    this.customQuality,
    this.customImageQuality,
    this.compressImages = true,
    this.removeMetadata = false,
    this.removeFonts = false,
    this.removeAnnotations = false,
    this.linearize = true,
  });

  /// Get effective quality based on level or custom setting
  int get effectiveQuality {
    if (level == CompressionLevel.custom) {
      return customQuality ?? 50;
    }
    return level.quality;
  }

  /// Get effective image quality
  int get effectiveImageQuality {
    if (level == CompressionLevel.custom) {
      return customImageQuality ?? 50;
    }
    return level.imageQuality;
  }

  CompressionOptions copyWith({
    CompressionLevel? level,
    int? customQuality,
    int? customImageQuality,
    bool? compressImages,
    bool? removeMetadata,
    bool? removeFonts,
    bool? removeAnnotations,
    bool? linearize,
  }) {
    return CompressionOptions(
      level: level ?? this.level,
      customQuality: customQuality ?? this.customQuality,
      customImageQuality: customImageQuality ?? this.customImageQuality,
      compressImages: compressImages ?? this.compressImages,
      removeMetadata: removeMetadata ?? this.removeMetadata,
      removeFonts: removeFonts ?? this.removeFonts,
      removeAnnotations: removeAnnotations ?? this.removeAnnotations,
      linearize: linearize ?? this.linearize,
    );
  }
}
