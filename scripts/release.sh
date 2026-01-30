#!/bin/bash

# PDF Toolkit Release Script
# Usage: ./scripts/release.sh <version> [android|windows|all]
#
# This script builds release artifacts for distribution:
# - Android: APK and App Bundle (AAB)
# - Windows: Executable with all dependencies (Windows only)
#
# Outputs are placed in: dist/v{version}/

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Arguments
VERSION=${1:-""}
TARGET=${2:-"all"}

# Validate version
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version is required${NC}"
    echo "Usage: ./scripts/release.sh <version> [android|windows|all]"
    echo "Example: ./scripts/release.sh 1.0.0 all"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${RED}Error: Invalid version format. Use SemVer: x.y.z or x.y.z-tag${NC}"
    exit 1
fi

# Banner
echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║              PDF Toolkit Release Builder                 ║${NC}"
echo -e "${MAGENTA}║                    Version ${VERSION}                         ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Setup directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/dist/v$VERSION"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

echo -e "${CYAN}Preparing release directories...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
echo -e "${GREEN}Created: $DIST_DIR${NC}"

# Check Flutter
echo -e "\n${CYAN}Checking Flutter installation...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi
echo -e "${GREEN}Flutter found!${NC}"

# Clean and get dependencies
echo -e "\n${CYAN}Cleaning previous builds...${NC}"
cd "$PROJECT_ROOT"
flutter clean > /dev/null 2>&1 || true
echo -e "${GREEN}Clean complete${NC}"

echo -e "\n${CYAN}Getting dependencies...${NC}"
flutter pub get
echo -e "${GREEN}Dependencies installed${NC}"

# Build Android
if [ "$TARGET" = "android" ] || [ "$TARGET" = "all" ]; then
    echo -e "\n${CYAN}Building Android APK...${NC}"

    flutter build apk --release --build-name="$VERSION" --build-number=1
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        cp "build/app/outputs/flutter-apk/app-release.apk" "$DIST_DIR/pdf-toolkit-v$VERSION.apk"
        APK_SIZE=$(du -h "$DIST_DIR/pdf-toolkit-v$VERSION.apk" | cut -f1)
        echo -e "${GREEN}APK built: pdf-toolkit-v$VERSION.apk ($APK_SIZE)${NC}"
    fi

    echo -e "${YELLOW}Building App Bundle (AAB)...${NC}"
    flutter build appbundle --release --build-name="$VERSION" --build-number=1 || true
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        cp "build/app/outputs/bundle/release/app-release.aab" "$DIST_DIR/pdf-toolkit-v$VERSION.aab"
        AAB_SIZE=$(du -h "$DIST_DIR/pdf-toolkit-v$VERSION.aab" | cut -f1)
        echo -e "${GREEN}AAB built: pdf-toolkit-v$VERSION.aab ($AAB_SIZE)${NC}"
    fi
fi

# Build Windows (only on Windows/MSYS)
if [ "$TARGET" = "windows" ] || [ "$TARGET" = "all" ]; then
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo -e "\n${CYAN}Building Windows executable...${NC}"

        flutter build windows --release --build-name="$VERSION" --build-number=1
        if [ -d "build/windows/x64/runner/Release" ]; then
            cp -r "build/windows/x64/runner/Release" "$DIST_DIR/pdf-toolkit-v$VERSION-windows"

            # Create ZIP if zip is available
            if command -v zip &> /dev/null; then
                cd "$DIST_DIR"
                zip -r "pdf-toolkit-v$VERSION-windows.zip" "pdf-toolkit-v$VERSION-windows"
                cd "$PROJECT_ROOT"
                ZIP_SIZE=$(du -h "$DIST_DIR/pdf-toolkit-v$VERSION-windows.zip" | cut -f1)
                echo -e "${GREEN}Windows ZIP: pdf-toolkit-v$VERSION-windows.zip ($ZIP_SIZE)${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Skipping Windows build (not on Windows)${NC}"
    fi
fi

# Generate checksums
echo -e "\n${CYAN}Generating checksums...${NC}"
CHECKSUM_FILE="$DIST_DIR/checksums-sha256.txt"
cd "$DIST_DIR"
for file in *.apk *.aab *.zip 2>/dev/null; do
    if [ -f "$file" ]; then
        if command -v sha256sum &> /dev/null; then
            sha256sum "$file" >> "$CHECKSUM_FILE"
        elif command -v shasum &> /dev/null; then
            shasum -a 256 "$file" >> "$CHECKSUM_FILE"
        fi
    fi
done
cd "$PROJECT_ROOT"
echo -e "${GREEN}Checksums saved to checksums-sha256.txt${NC}"

# Generate release notes
cat > "$DIST_DIR/RELEASE_NOTES.md" << EOF
# PDF Toolkit v$VERSION

Released: $(date +"%Y-%m-%d")

## Downloads

See files in this directory.

## What's New

See [CHANGELOG.md](../CHANGELOG.md) for full details.

## Installation

### Android
1. Download the APK file
2. Enable "Install from unknown sources" if prompted
3. Open the APK to install

### Windows
1. Download and extract the ZIP file
2. Run \`pdf_toolkit.exe\`
3. No installation required (portable)

## Checksums (SHA-256)

\`\`\`
$(cat "$CHECKSUM_FILE" 2>/dev/null || echo "No checksums generated")
\`\`\`
EOF

echo -e "${GREEN}Release notes generated${NC}"

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Release Build Complete                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Output directory: ${CYAN}$DIST_DIR${NC}"
echo ""
echo "Files created:"
ls -la "$DIST_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Test the builds on target devices"
echo "  2. Create git tag: git tag -a v$VERSION -m 'Release v$VERSION'"
echo "  3. Push tag: git push origin v$VERSION"
echo "  4. Upload artifacts to GitHub Releases"
echo ""
