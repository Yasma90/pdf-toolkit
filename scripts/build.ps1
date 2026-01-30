# PDF Toolkit Build Script for Windows
# Usage: .\scripts\build.ps1 -target [android|windows|all]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("android", "windows", "all")]
    [string]$target = "all"
)

$ErrorActionPreference = "Stop"

Write-Host "PDF Toolkit Build Script" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Check Flutter installation
Write-Host "`nChecking Flutter installation..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "Flutter found!" -ForegroundColor Green

# Clean previous builds
Write-Host "`nCleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Clean failed, continuing..." -ForegroundColor Yellow
}

# Get dependencies
Write-Host "`nGetting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get dependencies" -ForegroundColor Red
    exit 1
}

# Build Android APK
if ($target -eq "android" -or $target -eq "all") {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building Android APK..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    flutter build apk --release
    if ($LASTEXITCODE -eq 0) {
        $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $apkSize = (Get-Item $apkPath).Length / 1MB
            Write-Host "`nAndroid APK built successfully!" -ForegroundColor Green
            Write-Host "Location: $apkPath" -ForegroundColor White
            Write-Host "Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
        }
    } else {
        Write-Host "Error: Android build failed" -ForegroundColor Red
    }
}

# Build Windows
if ($target -eq "windows" -or $target -eq "all") {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building Windows executable..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    flutter build windows --release
    if ($LASTEXITCODE -eq 0) {
        $exePath = "build\windows\x64\runner\Release\pdf_toolkit.exe"
        if (Test-Path $exePath) {
            Write-Host "`nWindows build successful!" -ForegroundColor Green
            Write-Host "Location: build\windows\x64\runner\Release\" -ForegroundColor White
        }
    } else {
        Write-Host "Error: Windows build failed" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build process completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
