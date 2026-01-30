# PDF Toolkit Release Script for Windows
# Usage: .\scripts\release.ps1 -version "1.0.0" [-target android|windows|all]
#
# This script builds release artifacts for distribution:
# - Android: APK and App Bundle (AAB)
# - Windows: Executable with all dependencies
#
# Outputs are placed in: dist/v{version}/

param(
    [Parameter(Mandatory=$true)]
    [string]$version,

    [Parameter(Mandatory=$false)]
    [ValidateSet("android", "windows", "all")]
    [string]$target = "all"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Header { param($msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║              PDF Toolkit Release Builder                 ║" -ForegroundColor Magenta
Write-Host "║                    Version $version                         ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Validate version format (SemVer)
if ($version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9]+)?$') {
    Write-Error "Invalid version format. Use SemVer: x.y.z or x.y.z-tag"
    exit 1
}

# Setup directories
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $projectRoot) { $projectRoot = Get-Location }
$distDir = Join-Path $projectRoot "dist\v$version"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"

Write-Header "Preparing release directories..."
if (Test-Path $distDir) {
    Write-Warning "Directory exists, cleaning..."
    Remove-Item -Recurse -Force $distDir
}
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
Write-Success "Created: $distDir"

# Check Flutter
Write-Header "Checking Flutter installation..."
$flutterVersion = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter is not installed or not in PATH"
    exit 1
}
Write-Success "Flutter found!"

# Clean and get dependencies
Write-Header "Cleaning previous builds..."
flutter clean 2>&1 | Out-Null
Write-Success "Clean complete"

Write-Header "Getting dependencies..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get dependencies"
    exit 1
}
Write-Success "Dependencies installed"

# Build Android
if ($target -eq "android" -or $target -eq "all") {
    Write-Header "Building Android APK..."
    Write-Host "Building release APK..." -ForegroundColor Yellow

    flutter build apk --release --build-name=$version --build-number=1
    if ($LASTEXITCODE -eq 0) {
        $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkSource) {
            $apkDest = Join-Path $distDir "pdf-toolkit-v$version.apk"
            Copy-Item $apkSource $apkDest
            $apkSize = [math]::Round((Get-Item $apkDest).Length / 1MB, 2)
            Write-Success "APK built: pdf-toolkit-v$version.apk ($apkSize MB)"
        }
    } else {
        Write-Error "APK build failed"
    }

    Write-Host "Building App Bundle (AAB)..." -ForegroundColor Yellow
    flutter build appbundle --release --build-name=$version --build-number=1
    if ($LASTEXITCODE -eq 0) {
        $aabSource = "build\app\outputs\bundle\release\app-release.aab"
        if (Test-Path $aabSource) {
            $aabDest = Join-Path $distDir "pdf-toolkit-v$version.aab"
            Copy-Item $aabSource $aabDest
            $aabSize = [math]::Round((Get-Item $aabDest).Length / 1MB, 2)
            Write-Success "AAB built: pdf-toolkit-v$version.aab ($aabSize MB)"
        }
    } else {
        Write-Warning "AAB build failed (non-critical)"
    }
}

# Build Windows
if ($target -eq "windows" -or $target -eq "all") {
    Write-Header "Building Windows executable..."

    flutter build windows --release --build-name=$version --build-number=1
    if ($LASTEXITCODE -eq 0) {
        $winSource = "build\windows\x64\runner\Release"
        if (Test-Path $winSource) {
            $winDest = Join-Path $distDir "pdf-toolkit-v$version-windows"
            Copy-Item -Recurse $winSource $winDest

            # Create ZIP
            $zipPath = Join-Path $distDir "pdf-toolkit-v$version-windows.zip"
            Compress-Archive -Path $winDest -DestinationPath $zipPath
            $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
            Write-Success "Windows ZIP: pdf-toolkit-v$version-windows.zip ($zipSize MB)"
        }
    } else {
        Write-Error "Windows build failed"
    }
}

# Generate checksums
Write-Header "Generating checksums..."
$checksumFile = Join-Path $distDir "checksums-sha256.txt"
Get-ChildItem $distDir -File | Where-Object { $_.Extension -in ".apk", ".aab", ".zip" } | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    "$hash  $($_.Name)" | Add-Content $checksumFile
}
Write-Success "Checksums saved to checksums-sha256.txt"

# Generate release notes template
$releaseNotesPath = Join-Path $distDir "RELEASE_NOTES.md"
@"
# PDF Toolkit v$version

Released: $(Get-Date -Format "yyyy-MM-dd")

## Downloads

| Platform | File | Size |
|----------|------|------|
$(if (Test-Path (Join-Path $distDir "pdf-toolkit-v$version.apk")) {
    $size = [math]::Round((Get-Item (Join-Path $distDir "pdf-toolkit-v$version.apk")).Length / 1MB, 2)
    "| Android APK | pdf-toolkit-v$version.apk | $size MB |"
})
$(if (Test-Path (Join-Path $distDir "pdf-toolkit-v$version.aab")) {
    $size = [math]::Round((Get-Item (Join-Path $distDir "pdf-toolkit-v$version.aab")).Length / 1MB, 2)
    "| Android AAB | pdf-toolkit-v$version.aab | $size MB |"
})
$(if (Test-Path (Join-Path $distDir "pdf-toolkit-v$version-windows.zip")) {
    $size = [math]::Round((Get-Item (Join-Path $distDir "pdf-toolkit-v$version-windows.zip")).Length / 1MB, 2)
    "| Windows | pdf-toolkit-v$version-windows.zip | $size MB |"
})

## What's New

See [CHANGELOG.md](../CHANGELOG.md) for full details.

## Installation

### Android
1. Download the APK file
2. Enable "Install from unknown sources" if prompted
3. Open the APK to install

### Windows
1. Download and extract the ZIP file
2. Run ``pdf_toolkit.exe``
3. No installation required (portable)

## Checksums (SHA-256)

``````
$(Get-Content $checksumFile -Raw)
``````
"@ | Set-Content $releaseNotesPath

Write-Success "Release notes generated"

# Summary
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                  Release Build Complete                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Output directory: $distDir" -ForegroundColor White
Write-Host ""
Write-Host "Files created:" -ForegroundColor White
Get-ChildItem $distDir | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the builds on target devices"
Write-Host "  2. Create git tag: git tag -a v$version -m 'Release v$version'"
Write-Host "  3. Push tag: git push origin v$version"
Write-Host "  4. Upload artifacts to GitHub Releases"
Write-Host ""
