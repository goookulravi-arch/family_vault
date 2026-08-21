import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/database/app_database.dart';
import '../../documents/views/document_details_screen.dart';
import '../../family_members/providers/family_member_providers.dart';

class FolderDetailsScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String folderId;

  const FolderDetailsScreen({
    super.key,
    required this.memberId,
    required this.folderId,
  });

  @override
  ConsumerState<FolderDetailsScreen> createState() =>
      _FolderDetailsScreenState();
}

class _FolderDetailsScreenState extends ConsumerState<FolderDetailsScreen> {
  bool _isLoading = true;
  bool _isLoadingDocuments = false;
  bool _isUploading = false;
  bool _isDeletingFolder = false;

  String _folderName = 'Folder Details';

  List<Document> _documents = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadFolder();
    });
  }

  // ============================================================
  // LOAD FOLDER
  // ============================================================

  Future<void> _loadFolder() async {
    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      final folder = await repo.getFolderById(
        widget.folderId,
      );

      if (!mounted) return;

      if (folder == null) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _folderName = folder.name;
        _isLoading = false;
      });

      await _loadDocuments();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Failed to load folder: $e',
      );
    }
  }

  // ============================================================
  // LOAD DOCUMENTS
  // ============================================================

  Future<void> _loadDocuments() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDocuments = true;
    });

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      final documents = await repo.getDocumentsInFolder(
        widget.folderId,
      );

      if (!mounted) return;

      setState(() {
        _documents = documents;
        _isLoadingDocuments = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingDocuments = false;
      });

      _showMessage(
        'Failed to load documents: $e',
      );
    }
  }

  // ============================================================
  // RENAME FOLDER
  // ============================================================

  Future<void> _renameFolder() async {
    if (_isDeletingFolder) return;

    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return RenameFolderDialog(
          currentName: _folderName,
        );
      },
    );

    if (!mounted || newName == null) {
      return;
    }

    final trimmedName = newName.trim();

    if (trimmedName.isEmpty || trimmedName == _folderName) {
      return;
    }

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.renameFolder(
        folderId: widget.folderId,
        newName: trimmedName,
      );

      if (!mounted) return;

      setState(() {
        _folderName = trimmedName;
      });

      _showMessage(
        'Folder renamed successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to rename folder: $e',
      );
    }
  }

  // ============================================================
  // DELETE FOLDER
  // ============================================================

  Future<void> _confirmDeleteFolder() async {
    if (_isDeletingFolder) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Folder?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"$_folderName"?\n\n'
            'All documents inside this folder '
            'will also be deleted.',
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

    if (!mounted || shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeletingFolder = true;
    });

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      final documents = await repo.getDocumentsInFolder(
        widget.folderId,
      );

      await repo.deleteFolder(
        widget.folderId,
      );

      for (final document in documents) {
        try {
          final file = File(
            document.filePath,
          );

          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Database deletion already succeeded.
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingFolder = false;
      });

      _showMessage(
        'Failed to delete folder: $e',
      );
    }
  }

  // ============================================================
  // PICK AND UPLOAD DOCUMENT
  // ============================================================

  Future<void> _pickAndUploadDocument() async {
    if (_isUploading || _isDeletingFolder) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        if (!mounted) return;

        setState(() {
          _isUploading = false;
        });

        return;
      }

      final pickedFile = result.files.single;

      final originalFile = File(
        pickedFile.path!,
      );

      if (!await originalFile.exists()) {
        throw Exception(
          'Selected file no longer exists.',
        );
      }

      final appDir = await getApplicationDocumentsDirectory();

      final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_'
          '${p.basename(pickedFile.name)}';

      final savedFilePath = p.join(
        appDir.path,
        safeFileName,
      );

      await originalFile.copy(
        savedFilePath,
      );

      final savedFile = File(savedFilePath);

      final fileStat = await savedFile.stat();

      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.addDocument(
        memberId: widget.memberId,
        folderId: widget.folderId,
        name: pickedFile.name,
        filePath: savedFilePath,
        fileType: pickedFile.extension?.toLowerCase() ?? 'unknown',
        fileSize: fileStat.size,
      );

      await _loadDocuments();

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showMessage(
        'Document uploaded successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showMessage(
        'Failed to upload document: $e',
      );
    }
  }

  // ============================================================
  // OPEN DOCUMENT DETAILS
  // ============================================================

  Future<void> _openDocumentDetails(
    Document document,
  ) async {
    if (_isDeletingFolder) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailsScreen(
          documentId: document.id,
        ),
      ),
    );

    if (!mounted) return;

    await _loadDocuments();
  }

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> _deleteDocument(
    Document document,
  ) async {
    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.deleteDocument(
        document.id,
      );

      final file = File(
        document.filePath,
      );

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Database deletion already succeeded.
        }
      }

      await _loadDocuments();

      if (!mounted) return;

      _showMessage(
        'Document deleted.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Failed to delete document: $e',
      );
    }
  }

  // ============================================================
  // CONFIRM DELETE DOCUMENT
  // ============================================================

  Future<void> _confirmDeleteDocument(
    Document document,
  ) async {
    if (_isDeletingFolder) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Document?',
          ),
          content: Text(
            'Are you sure you want to delete '
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

    if (!mounted || shouldDelete != true) {
      return;
    }

    await _deleteDocument(
      document,
    );
  }

  // ============================================================
  // IMAGE FILE CHECK
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
  // DOCUMENT ICON
  // ============================================================

  Widget _buildDocumentIcon(
    String fileType,
  ) {
    final type = fileType.toLowerCase();

    if (type == 'pdf') {
      return const Icon(
        Icons.picture_as_pdf,
        color: Colors.red,
        size: 30,
      );
    }

    if (_isImageFile(type)) {
      return const Icon(
        Icons.image,
        color: Colors.green,
        size: 30,
      );
    }

    if ([
      'doc',
      'docx',
    ].contains(type)) {
      return const Icon(
        Icons.description,
        color: Colors.blue,
        size: 30,
      );
    }

    if ([
      'xls',
      'xlsx',
      'csv',
    ].contains(type)) {
      return const Icon(
        Icons.table_chart,
        color: Colors.green,
        size: 30,
      );
    }

    if ([
      'ppt',
      'pptx',
    ].contains(type)) {
      return const Icon(
        Icons.slideshow,
        color: Colors.orange,
        size: 30,
      );
    }

    if ([
      'txt',
      'rtf',
    ].contains(type)) {
      return const Icon(
        Icons.text_snippet,
        color: Colors.grey,
        size: 30,
      );
    }

    if ([
      'zip',
      'rar',
      '7z',
    ].contains(type)) {
      return const Icon(
        Icons.folder_zip,
        size: 30,
      );
    }

    return const Icon(
      Icons.insert_drive_file,
      color: Colors.blue,
      size: 30,
    );
  }

  // ============================================================
  // DOCUMENT PREVIEW
  // ============================================================

  Widget _buildDocumentPreview(
    Document document,
  ) {
    if (!_isImageFile(
      document.fileType,
    )) {
      return _buildDocumentIcon(
        document.fileType,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(document.filePath),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return _buildDocumentIcon(
            document.fileType,
          );
        },
      ),
    );
  }

  // ============================================================
  // DOCUMENT TYPE LABEL
  // ============================================================

  String _documentTypeLabel(
    Document document,
  ) {
    final type = document.fileType.trim();

    if (type.isEmpty || type.toLowerCase() == 'unknown') {
      return 'FILE';
    }

    return type.toUpperCase();
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
  // DOCUMENT LIST
  // ============================================================

  Widget _buildDocumentList() {
    if (_isLoadingDocuments) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open,
                size: 72,
                color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: 0.35,
                    ),
              ),
              const SizedBox(
                height: 16,
              ),
              const Text(
                'No documents inside this folder yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton.icon(
                onPressed: _isUploading || _isDeletingFolder
                    ? null
                    : _pickAndUploadDocument,
                icon: const Icon(
                  Icons.upload_file,
                ),
                label: const Text(
                  'Add Document',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        itemBuilder: (
          context,
          index,
        ) {
          final document = _documents[index];

          return Card(
            key: ValueKey(
              document.id,
            ),
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: _buildDocumentPreview(
                document,
              ),
              title: Text(
                document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${_documentTypeLabel(document)} • '
                      '${_formatFileSize(document.fileSize)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Open Document',
                    icon: const Icon(
                      Icons.open_in_new,
                    ),
                    onPressed: _isDeletingFolder
                        ? null
                        : () => _openDocumentDetails(
                              document,
                            ),
                  ),
                  IconButton(
                    tooltip: 'Delete Document',
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    onPressed: _isDeletingFolder
                        ? null
                        : () => _confirmDeleteDocument(
                              document,
                            ),
                  ),
                ],
              ),
              onTap: _isDeletingFolder
                  ? null
                  : () => _openDocumentDetails(
                        document,
                      ),
            ),
          );
        },
      ),
    );
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
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _folderName,
        ),
        actions: [
          IconButton(
            tooltip: 'Rename Folder',
            icon: const Icon(
              Icons.edit,
            ),
            onPressed: _isDeletingFolder ? null : _renameFolder,
          ),
          IconButton(
            tooltip: 'Delete Folder',
            icon: _isDeletingFolder
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
            onPressed: _isDeletingFolder ? null : _confirmDeleteFolder,
          ),
          IconButton(
            tooltip: 'Add Document',
            icon: _isUploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.upload_file,
                  ),
            onPressed: _isUploading || _isDeletingFolder
                ? null
                : _pickAndUploadDocument,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _buildDocumentList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _isUploading || _isDeletingFolder ? null : _pickAndUploadDocument,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.add,
              ),
        label: Text(
          _isUploading ? 'Uploading...' : 'Add Document',
        ),
      ),
    );
  }
}

// ================================================================
// RENAME FOLDER DIALOG
// ================================================================

class RenameFolderDialog extends StatefulWidget {
  final String currentName;

  const RenameFolderDialog({
    super.key,
    required this.currentName,
  });

  @override
  State<RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<RenameFolderDialog> {
  late final TextEditingController _controller;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.currentName,
    );

    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _focusNode.requestFocus();

      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  void _rename() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      name,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: const Text(
        'Rename Folder',
      ),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLength: 150,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Folder Name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _rename(),
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
          onPressed: _rename,
          child: const Text(
            'Rename',
          ),
        ),
      ],
    );
  }
}
