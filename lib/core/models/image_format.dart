/// Supported image formats for PDF conversion
enum ImageFormat {
  png(
    name: 'PNG',
    extension: 'png',
    description: 'Lossless compression, supports transparency',
    mimeType: 'image/png',
  ),
  jpeg(
    name: 'JPEG',
    extension: 'jpg',
    description: 'Smaller file size, no transparency',
    mimeType: 'image/jpeg',
  ),
  webp(
    name: 'WebP',
    extension: 'webp',
    description: 'Modern format, best compression',
    mimeType: 'image/webp',
  );

  const ImageFormat({
    required this.name,
    required this.extension,
    required this.description,
    required this.mimeType,
  });

  final String name;
  final String extension;
  final String description;
  final String mimeType;
}

/// Image quality/resolution presets
enum ImageQuality {
  low(
    name: 'Low',
    description: 'Fast, smaller files',
    dpi: 72,
    quality: 60,
  ),
  medium(
    name: 'Medium',
    description: 'Balanced quality',
    dpi: 150,
    quality: 80,
  ),
  high(
    name: 'High',
    description: 'High quality',
    dpi: 300,
    quality: 90,
  ),
  print(
    name: 'Print',
    description: 'Professional printing',
    dpi: 600,
    quality: 100,
  );

  const ImageQuality({
    required this.name,
    required this.description,
    required this.dpi,
    required this.quality,
  });

  final String name;
  final String description;
  final int dpi;
  final int quality;
}

/// Options for PDF to image conversion
class ConversionOptions {
  final ImageFormat format;
  final ImageQuality quality;
  final List<int>? specificPages;
  final bool allPages;

  const ConversionOptions({
    this.format = ImageFormat.png,
    this.quality = ImageQuality.medium,
    this.specificPages,
    this.allPages = true,
  });

  ConversionOptions copyWith({
    ImageFormat? format,
    ImageQuality? quality,
    List<int>? specificPages,
    bool? allPages,
  }) {
    return ConversionOptions(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      specificPages: specificPages ?? this.specificPages,
      allPages: allPages ?? this.allPages,
    );
  }
}

/// Result of conversion operation
class ConversionResult {
  final List<String> outputPaths;
  final int totalImages;
  final int totalSize;
  final Duration processingTime;
  final ImageFormat format;

  const ConversionResult({
    required this.outputPaths,
    required this.totalImages,
    required this.totalSize,
    required this.processingTime,
    required this.format,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
