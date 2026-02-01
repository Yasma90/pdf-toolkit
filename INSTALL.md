# PDF Toolkit - Installation Guide

## Prerequisites

### Windows

1. **Git** - https://git-scm.com/download/win
2. **Android Studio** (for Android SDK) - https://developer.android.com/studio

## Installation from Scratch

### Step 1: Install JDK 17

```powershell
# Download and extract JDK 17
curl -L -o "$env:USERPROFILE\jdk.zip" "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"
Expand-Archive "$env:USERPROFILE\jdk.zip" -DestinationPath "$env:USERPROFILE" -Force
Remove-Item "$env:USERPROFILE\jdk.zip"

# Find extracted folder name (e.g., jdk-17.0.17+10)
$jdkFolder = Get-ChildItem "$env:USERPROFILE" -Directory | Where-Object { $_.Name -like "jdk-17*" } | Select-Object -First 1
Write-Host "JDK installed at: $env:USERPROFILE\$($jdkFolder.Name)"
```

### Step 2: Install Flutter SDK

```powershell
# Download Flutter SDK
curl -L -o "$env:USERPROFILE\flutter.zip" "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
Expand-Archive "$env:USERPROFILE\flutter.zip" -DestinationPath "$env:USERPROFILE" -Force
Remove-Item "$env:USERPROFILE\flutter.zip"

Write-Host "Flutter installed at: $env:USERPROFILE\flutter"
```

### Step 3: Configure Environment Variables

```powershell
# Set JAVA_HOME
$jdkFolder = (Get-ChildItem "$env:USERPROFILE" -Directory | Where-Object { $_.Name -like "jdk-17*" } | Select-Object -First 1).Name
[Environment]::SetEnvironmentVariable('JAVA_HOME', "$env:USERPROFILE\$jdkFolder", 'User')

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPaths = @(
    "$env:USERPROFILE\flutter\bin",
    "$env:USERPROFILE\$jdkFolder\bin",
    "$env:LOCALAPPDATA\Android\sdk\platform-tools"
) -join ';'

[Environment]::SetEnvironmentVariable('Path', "$newPaths;$currentPath", 'User')

Write-Host "Environment variables configured. Restart your terminal."
```

### Step 4: Accept Android Licenses

```powershell
# Restart terminal first, then run:
flutter doctor --android-licenses
```

### Step 5: Verify Installation

```powershell
flutter doctor
```

Expected output should show:
- [✓] Flutter
- [✓] Android toolchain
- [✓] Android Studio (or VS Code)

## Clone and Build

### Clone Repository

```powershell
git clone https://github.com/YOUR_USERNAME/pdf-toolkit.git
cd pdf-toolkit
```

### Install Dependencies

```powershell
flutter pub get
```

### Build APK

```powershell
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for distribution)
flutter build apk --release
```

## Output Locations

| Build Type | Location |
|------------|----------|
| Debug APK | `build\app\outputs\flutter-apk\app-debug.apk` |
| Release APK | `build\app\outputs\flutter-apk\app-release.apk` |
| App Bundle | `build\app\outputs\bundle\release\app-release.aab` |
| Windows EXE | `build\windows\x64\runner\Release\` |

## Common Issues

### "flutter: command not found"
Restart your terminal or run:
```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
```

### "JAVA_HOME not set"
```powershell
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
```

### Gradle build fails with resource errors
Run `flutter clean` and try again.

## Development Setup

### Run on Device/Emulator

```powershell
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run on all connected devices
flutter run -d all
```

### Hot Reload

Press `r` in the terminal while the app is running.

### Hot Restart

Press `R` (capital) in the terminal while the app is running.

## Windows Build (Optional)

```powershell
# Enable Windows desktop support
flutter config --enable-windows-desktop

# Build Windows app
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\pdf_toolkit.exe`
