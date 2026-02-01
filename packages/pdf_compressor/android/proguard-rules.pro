# BouncyCastle - Required by iText for PDF encryption
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# iText PDF library
-keep class com.itextpdf.** { *; }
-dontwarn com.itextpdf.**

# Keep the plugin class
-keep class com.kaizen404.pdf_compressor.** { *; }
