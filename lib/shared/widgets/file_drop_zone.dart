import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:pdf_toolkit/shared/theme/app_theme.dart';

class FileDropZone extends StatefulWidget {
  final VoidCallback onTap;
  final Function(List<String> paths)? onFilesDropped;
  final bool isLoading;
  final String? selectedFileName;
  final String? fileSize;
  final VoidCallback? onClear;
  final bool multiple;

  const FileDropZone({
    super.key,
    required this.onTap,
    this.onFilesDropped,
    this.isLoading = false,
    this.selectedFileName,
    this.fileSize,
    this.onClear,
    this.multiple = false,
  });

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleDrop(DropDoneDetails details) {
    if (widget.isLoading) return;

    final pdfPaths = details.files
        .where((file) => file.path.toLowerCase().endsWith('.pdf'))
        .map((file) => file.path)
        .toList();

    if (pdfPaths.isNotEmpty) {
      if (widget.onFilesDropped != null) {
        widget.onFilesDropped!(widget.multiple ? pdfPaths : [pdfPaths.first]);
      }
    }

    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.selectedFileName != null;

    return DropTarget(
      onDragEntered: (_) {
        if (!widget.isLoading) {
          setState(() => _isDragging = true);
        }
      },
      onDragExited: (_) {
        setState(() => _isDragging = false);
      },
      onDragDone: _handleDrop,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedBuilder(
          listenable: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: hasFile ? 1.0 : _pulseAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _isDragging
                  ? AppColors.primary.withOpacity(0.1)
                  : hasFile
                      ? AppColors.success.withOpacity(0.05)
                      : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDragging
                    ? AppColors.primary
                    : hasFile
                        ? AppColors.success.withOpacity(0.5)
                        : Theme.of(context).dividerColor,
                width: _isDragging ? 2 : 1,
                style: hasFile ? BorderStyle.solid : BorderStyle.none,
              ),
              boxShadow: _isDragging
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: DashedBorder(
              color: _isDragging
                  ? AppColors.primary
                  : hasFile
                      ? Colors.transparent
                      : AppColors.textSecondary.withOpacity(0.3),
              strokeWidth: 2,
              gap: 8,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: widget.isLoading
                    ? _buildLoadingContent()
                    : hasFile
                        ? _buildFileContent()
                        : _buildEmptyContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isDragging
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isDragging ? Icons.file_download : Icons.cloud_upload_outlined,
            size: 48,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isDragging
              ? 'Drop PDF file${widget.multiple ? 's' : ''} here'
              : widget.multiple ? 'Select PDF Files' : 'Select a PDF File',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _isDragging ? AppColors.primary : null,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Click to browse or drag & drop here',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'PDF files only',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                size: 32,
                color: AppColors.success,
              ),
            ),
            if (widget.onClear != null) ...[
              const Spacer(),
              IconButton(
                onPressed: widget.onClear,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.1),
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.selectedFileName!,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (widget.fileSize != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.fileSize!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: widget.onTap,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Change file'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Processing...',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please wait while we process your file',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

/// Custom dashed border painter
class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;
  final BorderRadius borderRadius;

  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 1,
    this.gap = 5,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        gap: gap,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final BorderRadius borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    path.addRRect(borderRadius.toRRect(rect));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? gap : gap / 2;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
