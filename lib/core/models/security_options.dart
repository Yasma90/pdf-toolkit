/// PDF security and encryption options
class SecurityOptions {
  final String userPassword;
  final String? ownerPassword;
  final PdfPermissions permissions;
  final EncryptionLevel encryptionLevel;

  const SecurityOptions({
    required this.userPassword,
    this.ownerPassword,
    this.permissions = const PdfPermissions(),
    this.encryptionLevel = EncryptionLevel.aes256,
  });

  /// Effective owner password (defaults to user password if not set)
  String get effectiveOwnerPassword => ownerPassword ?? userPassword;

  SecurityOptions copyWith({
    String? userPassword,
    String? ownerPassword,
    PdfPermissions? permissions,
    EncryptionLevel? encryptionLevel,
  }) {
    return SecurityOptions(
      userPassword: userPassword ?? this.userPassword,
      ownerPassword: ownerPassword ?? this.ownerPassword,
      permissions: permissions ?? this.permissions,
      encryptionLevel: encryptionLevel ?? this.encryptionLevel,
    );
  }
}

/// PDF permissions that can be restricted
class PdfPermissions {
  final bool allowPrinting;
  final bool allowModifying;
  final bool allowCopying;
  final bool allowAnnotations;
  final bool allowFillingForms;
  final bool allowAccessibility;
  final bool allowAssembly;
  final bool allowHighQualityPrint;

  const PdfPermissions({
    this.allowPrinting = true,
    this.allowModifying = false,
    this.allowCopying = true,
    this.allowAnnotations = true,
    this.allowFillingForms = true,
    this.allowAccessibility = true,
    this.allowAssembly = false,
    this.allowHighQualityPrint = true,
  });

  /// All permissions enabled
  static const PdfPermissions allowAll = PdfPermissions(
    allowPrinting: true,
    allowModifying: true,
    allowCopying: true,
    allowAnnotations: true,
    allowFillingForms: true,
    allowAccessibility: true,
    allowAssembly: true,
    allowHighQualityPrint: true,
  );

  /// All permissions disabled (most restrictive)
  static const PdfPermissions denyAll = PdfPermissions(
    allowPrinting: false,
    allowModifying: false,
    allowCopying: false,
    allowAnnotations: false,
    allowFillingForms: false,
    allowAccessibility: false,
    allowAssembly: false,
    allowHighQualityPrint: false,
  );

  /// View only - can't print, modify, or copy
  static const PdfPermissions viewOnly = PdfPermissions(
    allowPrinting: false,
    allowModifying: false,
    allowCopying: false,
    allowAnnotations: false,
    allowFillingForms: false,
    allowAccessibility: true,
    allowAssembly: false,
    allowHighQualityPrint: false,
  );

  PdfPermissions copyWith({
    bool? allowPrinting,
    bool? allowModifying,
    bool? allowCopying,
    bool? allowAnnotations,
    bool? allowFillingForms,
    bool? allowAccessibility,
    bool? allowAssembly,
    bool? allowHighQualityPrint,
  }) {
    return PdfPermissions(
      allowPrinting: allowPrinting ?? this.allowPrinting,
      allowModifying: allowModifying ?? this.allowModifying,
      allowCopying: allowCopying ?? this.allowCopying,
      allowAnnotations: allowAnnotations ?? this.allowAnnotations,
      allowFillingForms: allowFillingForms ?? this.allowFillingForms,
      allowAccessibility: allowAccessibility ?? this.allowAccessibility,
      allowAssembly: allowAssembly ?? this.allowAssembly,
      allowHighQualityPrint: allowHighQualityPrint ?? this.allowHighQualityPrint,
    );
  }
}

/// Encryption levels for PDF protection
enum EncryptionLevel {
  /// 40-bit RC4 - weakest, maximum compatibility
  rc4_40(
    name: 'RC4 40-bit',
    description: 'Legacy, maximum compatibility',
    bits: 40,
  ),

  /// 128-bit RC4 - moderate security
  rc4_128(
    name: 'RC4 128-bit',
    description: 'Good compatibility',
    bits: 128,
  ),

  /// 128-bit AES - good security
  aes128(
    name: 'AES 128-bit',
    description: 'Strong security',
    bits: 128,
  ),

  /// 256-bit AES - strongest security
  aes256(
    name: 'AES 256-bit',
    description: 'Maximum security (recommended)',
    bits: 256,
  );

  const EncryptionLevel({
    required this.name,
    required this.description,
    required this.bits,
  });

  final String name;
  final String description;
  final int bits;
}

/// Result of protection operation
class ProtectionResult {
  final String outputPath;
  final EncryptionLevel encryptionLevel;
  final bool hasUserPassword;
  final bool hasOwnerPassword;
  final Duration processingTime;

  const ProtectionResult({
    required this.outputPath,
    required this.encryptionLevel,
    required this.hasUserPassword,
    required this.hasOwnerPassword,
    required this.processingTime,
  });
}

/// Permission preset for quick selection
enum PermissionPreset {
  full(
    name: 'Full Access',
    description: 'All operations allowed',
    icon: '🔓',
  ),
  noModify(
    name: 'No Modifications',
    description: 'Print and copy allowed',
    icon: '📄',
  ),
  viewOnly(
    name: 'View Only',
    description: 'No print, copy, or modify',
    icon: '👁️',
  ),
  custom(
    name: 'Custom',
    description: 'Configure permissions',
    icon: '⚙️',
  );

  const PermissionPreset({
    required this.name,
    required this.description,
    required this.icon,
  });

  final String name;
  final String description;
  final String icon;

  PdfPermissions get permissions {
    switch (this) {
      case PermissionPreset.full:
        return PdfPermissions.allowAll;
      case PermissionPreset.noModify:
        return const PdfPermissions(
          allowPrinting: true,
          allowCopying: true,
          allowModifying: false,
          allowAnnotations: false,
          allowAssembly: false,
        );
      case PermissionPreset.viewOnly:
        return PdfPermissions.viewOnly;
      case PermissionPreset.custom:
        return const PdfPermissions();
    }
  }
}
