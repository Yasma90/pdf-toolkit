---
description: Build the PDF Toolkit for Android (APK) and Windows
---

Este workflow te permite compilar la aplicación para Android y Windows utilizando los scripts preconfigurados.

### Prerrequisitos

- Tener instalado el Flutter SDK (versión 3.2.0 o superior).
- Tener configurado el Android SDK para el APK.
- Tener instalado Visual Studio 2022 con desarrollo para escritorio con C++ para la versión de Windows.

### Pasos para compilar:

1. **Obtener dependencias:**

   ```powershell
   flutter pub get
   ```

2. **Compilar usando el script de construcción (Rápido):**
   // turbo

   ```powershell
   .\scripts\build.ps1 -target all
   ```

   _Esto generará el APK en `build\app\outputs\flutter-apk\app-release.apk` y el ejecutable de Windows en `build\windows\x64\runner\Release\`._

3. **Generar una versión de lanzamiento (Completo):**
   Si deseas generar un paquete de distribución con número de versión, notas de lanzamiento y checksums:
   ```powershell
   .\scripts\release.ps1 -version "1.0.0" -target all
   ```
   _Los archivos resultantes se guardarán en la carpeta `dist\v1.0.0\`._

### Ubicación de los archivos generados:

- **Android APK:** `build\app\outputs\flutter-apk\app-release.apk`
- **Windows EXE:** `build\windows\x64\runner\Release\pdf_toolkit.exe`
