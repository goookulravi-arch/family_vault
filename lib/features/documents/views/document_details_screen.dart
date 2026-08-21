import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../../data/database/app_database.dart';
import '../../family_members/providers/family_member_providers.dart';

class DocumentDetailsScreen extends ConsumerStatefulWidget {
  final String documentId;

  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
  });

  @override
  ConsumerState<DocumentDetailsScreen> createState() =>
      _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends ConsumerState<DocumentDetailsScreen> {
  bool _isLoading = true;
  bool _isOpening = false;
  bool _isDeleting = false;
  bool _isRenaming = false;

  Document? _document;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadDocument();
    });
  }

  // ============================================================
  // LOAD DOCUMENT
  // ============================================================

  Future<void> _loadDocument() async {
    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      final document = await repo.getDocumentById(
        widget.documentId,
      );

      if (!mounted) return;

      setState(() {
        _document = document;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Failed to load document: $e',
      );
    }
  }

  // ============================================================
  // OPEN DOCUMENT
  // ============================================================

  Future<void> _openDocument() async {
    final document = _document;

    if (document == null || _isOpening || _isDeleting || _isRenaming) {
      return;
    }

    setState(() {
      _isOpening = true;
    });

    try {
      final file = File(document.filePath);

      final exists = await file.exists();

      if (!exists) {
        if (!mounted) return;

        setState(() {
          _isOpening = false;
        });

        _showMessage(
          'File not found on this device.',
        );

        return;
      }

      final result = await OpenFilex.open(
        document.filePath,
      );

      if (!mounted) return;

      setState(() {
        _isOpening = false;
      });

      if (result.type != ResultType.done) {
        _showMessage(
          result.message.isNotEmpty
              ? result.message
              : 'Unable to open document.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isOpening = false;
      });

      _showMessage(
        'Unable to open document: $e',
      );
    }
  }

  // ============================================================
  // RENAME DOCUMENT
  // ============================================================

  Future<void> _renameDocument() async {
    final document = _document;

    if (document == null || _isRenaming || _isDeleting) {
      return;
    }

    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return RenameDocumentDialog(
          currentName: document.name,
        );
      },
    );

    if (!mounted || newName == null) {
      return;
    }

    final trimmedName = newName.trim();

    if (trimmedName.isEmpty || trimmedName == document.name.trim()) {
      return;
    }

    setState(() {
      _isRenaming = true;
    });

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.renameDocument(
        documentId: document.id,
        newName: trimmedName,
      );

      if (!mounted) return;

      setState(() {
        _document = document.copyWith(
          name: trimmedName,
        );

        _isRenaming = false;
      });

      _showMessage(
        'Document renamed successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRenaming = false;
      });

      _showMessage(
        'Failed to rename document: $e',
      );
    }
  }

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> _deleteDocument() async {
    final document = _document;

    if (document == null || _isDeleting || _isRenaming) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Delete Document?',
          ),
          content: Text(
            'Are you sure you want to '
            'permanently delete '
            '"${document.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.deleteDocument(
        document.id,
      );

      final file = File(document.filePath);

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Database deletion already succeeded.
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      _showMessage(
        'Failed to delete document: $e',
      );
    }
  }

  // ============================================================
  // IMAGE CHECK
  // ============================================================

  bool _isImageFile(
    String fileType,
  ) {
    return [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(
      fileType.toLowerCase(),
    );
  }

  // ============================================================
  // FILE ICON
  // ============================================================

  IconData _getFileIcon(
    String fileType,
  ) {
    final type = fileType.toLowerCase();

    if (type == 'pdf') {
      return Icons.picture_as_pdf;
    }

    if (_isImageFile(type)) {
      return Icons.image;
    }

    if ([
      'doc',
      'docx',
      'txt',
      'rtf',
    ].contains(type)) {
      return Icons.description;
    }

    if ([
      'xls',
      'xlsx',
      'csv',
    ].contains(type)) {
      return Icons.table_chart;
    }

    if ([
      'ppt',
      'pptx',
    ].contains(type)) {
      return Icons.slideshow;
    }

    if ([
      'zip',
      'rar',
      '7z',
    ].contains(type)) {
      return Icons.folder_zip;
    }

    return Icons.insert_drive_file;
  }

  // ============================================================
  // FILE TYPE NAME
  // ============================================================

  String _getFileTypeName(
    String fileType,
  ) {
    final type = fileType.trim().toLowerCase();

    if (type.isEmpty || type == 'unknown') {
      return 'Unknown';
    }

    switch (type) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return 'IMAGE • ${type.toUpperCase()}';

      case 'pdf':
        return 'PDF';

      case 'doc':
      case 'docx':
        return 'WORD • ${type.toUpperCase()}';

      case 'xls':
      case 'xlsx':
      case 'csv':
        return 'SPREADSHEET • ${type.toUpperCase()}';

      case 'ppt':
      case 'pptx':
        return 'PRESENTATION • ${type.toUpperCase()}';

      case 'txt':
      case 'rtf':
        return 'TEXT • ${type.toUpperCase()}';

      case 'zip':
      case 'rar':
      case '7z':
        return 'ARCHIVE • ${type.toUpperCase()}';

      default:
        return type.toUpperCase();
    }
  }

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  Widget _buildPreview(
    Document document,
  ) {
    if (!_isImageFile(
      document.fileType,
    )) {
      return Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(
            28,
          ),
        ),
        child: Icon(
          _getFileIcon(
            document.fileType,
          ),
          size: 76,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        24,
      ),
      child: Image.file(
        File(document.filePath),
        width: double.infinity,
        height: 260,
        fit: BoxFit.contain,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(
                28,
              ),
            ),
            child: Icon(
              Icons.broken_image,
              size: 72,
              color: Theme.of(
                context,
              ).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  String _formatFileSize(
    int bytes,
  ) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(
          2,
          '0',
        );

    final month = localDate.month.toString().padLeft(
          2,
          '0',
        );

    final year = localDate.year.toString();

    final hour = localDate.hour.toString().padLeft(
          2,
          '0',
        );

    final minute = localDate.minute.toString().padLeft(
          2,
          '0',
        );

    return '$day/$month/$year '
        '$hour:$minute';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: Theme.of(
          context,
        ).colorScheme.primary,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Document',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final document = _document;

    if (document == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Document',
          ),
        ),
        body: const Center(
          child: Text(
            'Document not found.',
          ),
        ),
      );
    }

    final extension = p.extension(
      document.name,
    );

    final isBusy = _isOpening || _isRenaming || _isDeleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Document Details',
        ),
        actions: [
          IconButton(
            tooltip: 'Rename',
            onPressed: isBusy ? null : _renameDocument,
            icon: _isRenaming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.edit,
                  ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: isBusy ? null : _deleteDocument,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(
          20,
        ),
        children: [
          // ======================================================
          // PREVIEW
          // ======================================================

          Center(
            child: _buildPreview(
              document,
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          // ======================================================
          // NAME
          // ======================================================

          Text(
            document.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            _getFileTypeName(
              document.fileType,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          // ======================================================
          // OPEN
          // ======================================================

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: isBusy ? null : _openDocument,
              icon: _isOpening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.open_in_new,
                    ),
              label: Text(
                _isOpening ? 'Opening...' : 'Open Document',
              ),
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          // ======================================================
          // FILE INFORMATION
          // ======================================================

          const Text(
            'File Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.insert_drive_file,
                    title: 'File type',
                    value: _getFileTypeName(
                      document.fileType,
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.storage,
                    title: 'File size',
                    value: _formatFileSize(
                      document.fileSize,
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    title: 'Added',
                    value: _formatDate(
                      document.createdAt,
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.folder,
                    title: 'Extension',
                    value: extension.isEmpty
                        ? 'None'
                        : extension
                            .replaceFirst(
                              '.',
                              '',
                            )
                            .toUpperCase(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          // ======================================================
          // RENAME
          // ======================================================

          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.edit,
              ),
              title: const Text(
                'Rename Document',
              ),
              subtitle: const Text(
                'Change the name shown in Family Vault',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: isBusy ? null : _renameDocument,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          // ======================================================
          // DELETE
          // ======================================================

          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text(
                'Delete Document',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
              subtitle: const Text(
                'Permanently remove this document',
              ),
              trailing: _isDeleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.chevron_right,
                      color: Colors.red,
                    ),
              onTap: isBusy ? null : _deleteDocument,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// RENAME DOCUMENT DIALOG
// ================================================================

class RenameDocumentDialog extends StatefulWidget {
  final String currentName;

  const RenameDocumentDialog({
    super.key,
    required this.currentName,
  });

  @override
  State<RenameDocumentDialog> createState() => _RenameDocumentDialogState();
}

class _RenameDocumentDialogState extends State<RenameDocumentDialog> {
  late final TextEditingController _controller;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.currentName,
    );

    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        _focusNode.requestFocus();

        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: const Text(
        'Rename Document',
      ),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLength: 150,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Document name',
          hintText: 'Enter document name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text(
            'Save',
          ),
        ),
      ],
    );
  }
}
