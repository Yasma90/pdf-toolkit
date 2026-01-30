# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Syncfusion
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Keep Riverpod
-keep class ** extends riverpod.** { *; }

# Keep PDF processing classes
-keep class com.pdftools.** { *; }
