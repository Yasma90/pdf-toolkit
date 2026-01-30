#!/bin/bash

# PDF Toolkit Build Script
# Usage: ./scripts/build.sh [android|windows|all]

set -e

TARGET=${1:-all}

echo "PDF Toolkit Build Script"
echo "========================"

# Check Flutter installation
echo -e "\nChecking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    exit 1
fi
echo "Flutter found!"

# Clean previous builds
echo -e "\nCleaning previous builds..."
flutter clean || true

# Get dependencies
echo -e "\nGetting dependencies..."
flutter pub get

# Build Android APK
if [ "$TARGET" = "android" ] || [ "$TARGET" = "all" ]; then
    echo -e "\n========================================"
    echo "Building Android APK..."
    echo "========================================"

    flutter build apk --release

    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
        echo -e "\nAndroid APK built successfully!"
        echo "Location: build/app/outputs/flutter-apk/app-release.apk"
        echo "Size: $APK_SIZE"
    fi
fi

# Build Windows (only on Windows)
if [ "$TARGET" = "windows" ] || [ "$TARGET" = "all" ]; then
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo -e "\n========================================"
        echo "Building Windows executable..."
        echo "========================================"

        flutter build windows --release

        if [ -d "build/windows/x64/runner/Release" ]; then
            echo -e "\nWindows build successful!"
            echo "Location: build/windows/x64/runner/Release/"
        fi
    else
        echo "Skipping Windows build (not on Windows)"
    fi
fi

echo -e "\n========================================"
echo "Build process completed!"
echo "========================================"
