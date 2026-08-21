import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileName;
  final String fileType;
  final int fileSize;
  final DateTime createdAt;

  const DocumentPreviewScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.createdAt,
  });

  bool get _isPdf {
    final extension = fileType.toLowerCase().replaceAll('.', '');
    return extension == 'pdf' || fileName.toLowerCase().endsWith('.pdf');
  }

  bool get _isImage {
    final extension = fileType.toLowerCase().replaceAll('.', '');

    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'gif' ||
        extension == 'webp' ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.gif') ||
        fileName.toLowerCase().endsWith('.webp');
  }

  String get _formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    }

    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }

    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openExternally(
    BuildContext context,
  ) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File not found on device.',
            ),
          ),
        );

        return;
      }

      await OpenFilex.open(filePath);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open document: $e',
          ),
        ),
      );
    }
  }

  void _showInformation(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _InfoRow(
                  label: 'Name',
                  value: fileName,
                ),
                _InfoRow(
                  label: 'Type',
                  value: fileType.isEmpty ? 'Unknown' : fileType.toUpperCase(),
                ),
                _InfoRow(
                  label: 'Size',
                  value: _formattedSize,
                ),
                _InfoRow(
                  label: 'Added',
                  value: '${createdAt.day.toString().padLeft(2, '0')}/'
                      '${createdAt.month.toString().padLeft(2, '0')}/'
                      '${createdAt.year}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline,
            ),
            tooltip: 'Information',
            onPressed: () {
              _showInformation(context);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.open_in_new,
            ),
            tooltip: 'Open externally',
            onPressed: () {
              _openExternally(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.data != true) {
            return _FileNotFoundView(
              onOpenExternally: () {
                _openExternally(context);
              },
            );
          }

          if (_isPdf) {
            return SfPdfViewer.file(
              file,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
            );
          }

          if (_isImage) {
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _FilePreviewError(
                      onOpenExternally: () {
                        _openExternally(context);
                      },
                    );
                  },
                ),
              ),
            );
          }

          return _UnsupportedFileView(
            fileName: fileName,
            onOpenExternally: () {
              _openExternally(context);
            },
          );
        },
      ),
    );
  }
}

// ================================================================
// INFORMATION ROW
// ================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FILE NOT FOUND
// ================================================================

class _FileNotFoundView extends StatelessWidget {
  final VoidCallback onOpenExternally;

  const _FileNotFoundView({
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 72,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'File not found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The original file is no longer available '
              'on this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenExternally,
              icon: const Icon(
                Icons.open_in_new,
              ),
              label: const Text(
                'Try External App',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// UNSUPPORTED FILE
// ================================================================

class _UnsupportedFileView extends StatelessWidget {
  final String fileName;
  final VoidCallback onOpenExternally;

  const _UnsupportedFileView({
    required this.fileName,
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 72,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preview unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Text(
              'This file type cannot be previewed inside '
              'Family Vault.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenExternally,
              icon: const Icon(
                Icons.open_in_new,
              ),
              label: const Text(
                'Open with another app',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PREVIEW ERROR
// ================================================================

class _FilePreviewError extends StatelessWidget {
  final VoidCallback onOpenExternally;

  const _FilePreviewError({
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          size: 64,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        const Text(
          'Unable to display this image.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpenExternally,
          icon: const Icon(
            Icons.open_in_new,
          ),
          label: const Text(
            'Open externally',
          ),
        ),
      ],
    );
  }
}
