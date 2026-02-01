# Windows Requirements for PDF Toolkit

## Ghostscript Installation (Required for PDF Compression)

PDF Toolkit uses Ghostscript on Windows to achieve professional-grade PDF compression with real image quality reduction. Without Ghostscript, the app will fall back to basic structure optimization which provides minimal file size reduction.

### Download and Install Ghostscript

1. **Download Ghostscript** from the official website:
   - https://ghostscript.com/releases/gsdnld.html
   - Choose the **64-bit** version for Windows (AGPL Release)
   - Recommended: Version 10.02.1 or newer

2. **Run the installer** with default settings
   - Default installation path: `C:\Program Files\gs\gs10.xx.x\`

3. **Verify installation**:
   - Open Command Prompt and run: `gswin64c -version`
   - You should see the Ghostscript version information

### Supported Ghostscript Versions

PDF Toolkit automatically detects Ghostscript in these locations:
- `C:\Program Files\gs\gs10.05.1\bin\gswin64c.exe`
- `C:\Program Files\gs\gs10.04.0\bin\gswin64c.exe`
- `C:\Program Files\gs\gs10.03.1\bin\gswin64c.exe`
- `C:\Program Files\gs\gs10.02.1\bin\gswin64c.exe`
- `C:\Program Files\gs\gs10.01.2\bin\gswin64c.exe`
- `C:\Program Files\gs\gs10.00.0\bin\gswin64c.exe`
- `C:\Program Files\gs\gs9.56.1\bin\gswin64c.exe`
- Or any version available in your system PATH

### Compression Levels with Ghostscript

When Ghostscript is available, these compression settings are applied:

| Level    | Image DPI | JPEG Quality | Best For                    |
|----------|-----------|--------------|------------------------------|
| Low      | 200 DPI   | 85%          | High-quality printing        |
| Medium   | 150 DPI   | 70%          | General use, email sharing   |
| High     | 100 DPI   | 50%          | Web uploads, archiving       |
| Extreme  | 72 DPI    | 30%          | Maximum compression, preview |

### Bundled Ghostscript (Optional)

For distribution, you can bundle Ghostscript with your application by placing the Ghostscript binaries in one of these locations relative to the executable:

- `data/ghostscript/gswin64c.exe`
- `ghostscript/gswin64c.exe`
- `gs/gswin64c.exe`

### Troubleshooting

**Compression not working or minimal reduction:**
1. Verify Ghostscript is installed: Open Command Prompt and run `where gswin64c.exe`
2. Make sure you installed the **64-bit** version
3. Restart PDF Toolkit after installing Ghostscript

**Error: "Ghostscript not found":**
- Ensure Ghostscript is installed in a standard location
- Or add Ghostscript's `bin` folder to your system PATH

## Without Ghostscript

On Windows without Ghostscript (or on Android), the app uses Syncfusion's built-in compression which:
- Optimizes PDF document structure
- Uses cross-reference streams
- Removes incremental updates
- Provides ~5-20% file size reduction (primarily for PDFs with minimal images)

For PDFs with many images, Ghostscript compression is **strongly recommended** as it can achieve 30-90% file size reduction.
