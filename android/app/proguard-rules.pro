# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core (deferred components) - ignore missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Syncfusion
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Keep Riverpod
-keep class ** extends riverpod.** { *; }

# Keep PDF processing classes
-keep class com.pdftools.** { *; }

# BouncyCastle - Required by iText for PDF encryption/compression
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# iText PDF library
-keep class com.itextpdf.** { *; }
-dontwarn com.itextpdf.**

# pdf_compressor plugin
-keep class com.kaizen404.pdf_compressor.** { *; }
