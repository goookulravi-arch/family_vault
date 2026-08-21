import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../providers/family_member_providers.dart';

class MemberDetailsScreen extends ConsumerStatefulWidget {
  final String memberId;

  const MemberDetailsScreen({
    super.key,
    required this.memberId,
  });

  @override
  ConsumerState<MemberDetailsScreen> createState() =>
      _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends ConsumerState<MemberDetailsScreen> {
  late Future<FamilyMember?> _memberFuture;
  late Future<List<CustomField>> _customFieldsFuture;
  late Future<List<Folder>> _foldersFuture;
  late Future<List<Document>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(
    covariant MemberDetailsScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.memberId != widget.memberId) {
      _loadData();
    }
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  void _loadData() {
    final repo = ref.read(
      familyMemberRepositoryProvider,
    );

    _memberFuture = repo.getMemberById(
      widget.memberId,
    );

    _customFieldsFuture = repo.getCustomFieldsForMember(
      widget.memberId,
    );

    _foldersFuture = repo.getFoldersForMember(
      widget.memberId,
    );

    _documentsFuture = repo.getRootDocumentsForMember(
      widget.memberId,
    );
  }

  void _refreshData() {
    if (!mounted) return;

    setState(() {
      _loadData();
    });
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ============================================================
  // DELETE FAMILY MEMBER
  // ============================================================

  Future<void> _confirmDelete(
    BuildContext context,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _DeleteMemberDialog(
          memberName: member.fullName,
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.deleteFamilyMember(
        member.id,
      );

      if (!mounted) return;

      context.pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete member: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // CREATE NEW FOLDER
  // ============================================================

  Future<void> _showAddFolderDialog(
    BuildContext context,
    String memberId,
  ) async {
    /*
     * IMPORTANT:
     *
     * The TextEditingController is now owned by the
     * _CreateFolderDialog widget itself.
     *
     * We DO NOT create a controller here.
     * We DO NOT manually dispose it here.
     *
     * This prevents:
     *
     * "A TextEditingController was used after being disposed."
     *
     * which was causing the secondary:
     *
     * "_dependents.isEmpty"
     *
     * Flutter framework assertion.
     */

    final folderName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const _CreateFolderDialog();
      },
    );

    // User cancelled.
    if (folderName == null || folderName.trim().isEmpty) {
      return;
    }

    if (!mounted) return;

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      /*
       * The dialog is already completely closed here.
       *
       * Now it is safe to perform the database operation.
       */
      await repo.createFolder(
        memberId: memberId,
        name: folderName.trim(),
      );

      if (!mounted) return;

      /*
       * Refresh on the next frame instead of rebuilding
       * immediately during the dialog/navigation lifecycle.
       */
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (!mounted) return;

          _refreshData();
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error creating folder: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // UPLOAD DOCUMENT
  // ============================================================

  Future<void> _pickAndUploadDocument(
    BuildContext context,
    String memberId, {
    String? folderId,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'doc',
          'docx',
          'txt',
        ],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = result.files.single;

      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.addDocument(
        memberId: memberId,
        folderId: folderId,
        name: file.name,
        filePath: file.path!,
        fileType: file.extension ?? 'unknown',
        fileSize: file.size,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded "${file.name}" successfully!',
          ),
        ),
      );

      _refreshData();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error uploading document: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> _confirmDeleteDocument(
    BuildContext context,
    Document doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Document?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${doc.name}"?',
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
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

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    try {
      final repo = ref.read(
        familyMemberRepositoryProvider,
      );

      await repo.deleteDocument(
        doc.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted "${doc.name}"',
          ),
        ),
      );

      _refreshData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete document: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FamilyMember?>(
      future: _memberFuture,
      builder: (
        context,
        memberSnapshot,
      ) {
        if (memberSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (memberSnapshot.hasError ||
            !memberSnapshot.hasData ||
            memberSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Member Details',
              ),
            ),
            body: const Center(
              child: Text(
                'Family member not found.',
              ),
            ),
          );
        }

        final member = memberSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              member.fullName,
            ),
            actions: [
              // ==================================================
              // EDIT
              // ==================================================

              IconButton(
                icon: const Icon(
                  Icons.edit,
                ),
                tooltip: 'Edit Member',
                onPressed: () async {
                  await context.push(
                    '/member/${member.id}/edit',
                  );

                  if (!mounted) return;

                  _refreshData();
                },
              ),

              // ==================================================
              // DELETE
              // ==================================================

              IconButton(
                icon: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                ),
                tooltip: 'Delete Member',
                onPressed: () {
                  _confirmDelete(
                    context,
                    member,
                  );
                },
              ),
            ],
          ),

          // ====================================================
          // MAIN CONTENT
          // ====================================================

          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ==================================================
              // PROFILE
              // ==================================================

              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: member.profileImagePath != null &&
                              File(
                                member.profileImagePath!,
                              ).existsSync()
                          ? FileImage(
                              File(
                                member.profileImagePath!,
                              ),
                            )
                          : null,
                      child: member.profileImagePath == null ||
                              !File(
                                member.profileImagePath!,
                              ).existsSync()
                          ? Text(
                              member.fullName.isNotEmpty
                                  ? member.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 40,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      member.fullName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    if (member.relationship != null &&
                        member.relationship!.isNotEmpty)
                      Text(
                        member.relationship!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // PERSONAL INFORMATION
              // ==================================================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Divider(),

                      // DATE OF BIRTH
                      if (member.dateOfBirth != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.cake,
                          ),
                          title: const Text(
                            'Date of Birth',
                          ),
                          subtitle: Text(
                            DateFormat(
                              'dd MMMM yyyy',
                            ).format(
                              member.dateOfBirth!,
                            ),
                          ),
                        ),

                      // GENDER
                      if (member.gender != null && member.gender!.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.person_outline,
                          ),
                          title: const Text(
                            'Gender',
                          ),
                          subtitle: Text(
                            member.gender!,
                          ),
                        ),

                      // PHONE
                      if (member.phone != null && member.phone!.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.phone,
                          ),
                          title: const Text(
                            'Phone',
                          ),
                          subtitle: Text(
                            member.phone!,
                          ),
                        ),

                      // EMAIL
                      if (member.email != null && member.email!.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.email,
                          ),
                          title: const Text(
                            'Email',
                          ),
                          subtitle: Text(
                            member.email!,
                          ),
                        ),

                      // ADDRESS
                      if (member.address != null && member.address!.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.home,
                          ),
                          title: const Text(
                            'Address',
                          ),
                          subtitle: Text(
                            member.address!,
                          ),
                        ),

                      // NOTES
                      if (member.notes != null && member.notes!.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.note,
                          ),
                          title: const Text(
                            'Notes',
                          ),
                          subtitle: Text(
                            member.notes!,
                          ),
                        ),

                      // ==================================================
                      // CUSTOM FIELDS
                      // ==================================================

                      FutureBuilder<List<CustomField>>(
                        future: _customFieldsFuture,
                        builder: (
                          context,
                          fieldSnapshot,
                        ) {
                          if (!fieldSnapshot.hasData ||
                              fieldSnapshot.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              ...fieldSnapshot.data!.map(
                                (field) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.info_outline,
                                    ),
                                    title: Text(
                                      field.fieldName,
                                    ),
                                    subtitle: Text(
                                      field.fieldValue,
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // FOLDERS & DOCUMENTS
              // ==================================================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // HEADER
                      // ==================================================

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Folders & Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // NEW FOLDER
                          IconButton(
                            icon: const Icon(
                              Icons.create_new_folder_outlined,
                            ),
                            tooltip: 'New Folder',
                            onPressed: () {
                              _showAddFolderDialog(
                                context,
                                member.id,
                              );
                            },
                          ),
                        ],
                      ),

                      const Divider(),

                      // ==================================================
                      // FOLDER LIST
                      // ==================================================

                      FutureBuilder<List<Folder>>(
                        future: _foldersFuture,
                        builder: (
                          context,
                          folderSnapshot,
                        ) {
                          final folders = folderSnapshot.data ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==================================================
                              // FOLDERS
                              // ==================================================

                              if (folders.isNotEmpty) ...[
                                const Text(
                                  'Folders',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: folders.length,
                                  itemBuilder: (
                                    context,
                                    index,
                                  ) {
                                    final folder = folders[index];

                                    return Card(
                                      key: ValueKey(
                                        'folder_${folder.id}',
                                      ),
                                      elevation: 1,
                                      color: Theme.of(
                                        context,
                                      )
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(
                                            alpha: 0.4,
                                          ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),

                                        // ==================================================
                                        // OPEN FOLDER
                                        // ==================================================

                                        onTap: () {
                                          /*
                                           * IMPORTANT:
                                           *
                                           * Do not await this navigation.
                                           * Do not refresh the parent after
                                           * pushing the folder screen.
                                           */
                                          context.push(
                                            '/member/${member.id}/folder/${folder.id}',
                                          );
                                        },

                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                            12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Icon(
                                                Icons.folder,
                                                size: 32,
                                                color: Colors.indigo,
                                              ),
                                              Text(
                                                folder.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                              ],

                              // ==================================================
                              // ROOT DOCUMENTS
                              // ==================================================

                              FutureBuilder<List<Document>>(
                                future: _documentsFuture,
                                builder: (
                                  context,
                                  docSnapshot,
                                ) {
                                  final docs = docSnapshot.data ?? [];

                                  // NOTHING
                                  if (folders.isEmpty && docs.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'No folders or documents added yet.\n'
                                          'Tap the folder button above to get started.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // NO ROOT DOCUMENTS
                                  if (docs.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  // ROOT DOCUMENTS
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Root Documents',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: docs.length,
                                        separatorBuilder: (
                                          _,
                                          __,
                                        ) =>
                                            const Divider(
                                          height: 1,
                                        ),
                                        itemBuilder: (
                                          context,
                                          index,
                                        ) {
                                          final doc = docs[index];

                                          final isPdf = doc.fileType
                                              .toLowerCase()
                                              .contains(
                                                'pdf',
                                              );

                                          return ListTile(
                                            dense: true,
                                            leading: Icon(
                                              isPdf
                                                  ? Icons.picture_as_pdf
                                                  : Icons.insert_drive_file,
                                              color: isPdf
                                                  ? Colors.red
                                                  : Colors.blue,
                                            ),
                                            title: Text(
                                              doc.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              '${_formatFileSize(doc.fileSize)} • '
                                              '${DateFormat('dd MMM yyyy').format(doc.createdAt)}',
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _confirmDeleteDocument(
                                                  context,
                                                  doc,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// CREATE FOLDER DIALOG
// ============================================================================

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();

    _focusNode = FocusNode();

    /*
     * Request focus after the dialog has been
     * inserted into the widget tree.
     */
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        _focusNode.requestFocus();
      },
    );
  }

  @override
  void dispose() {
    /*
     * The dialog owns both objects.
     *
     * They are disposed only when this dialog
     * State is actually removed from the tree.
     */
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  void _createFolder() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      return;
    }

    /*
     * Return the value to the parent.
     *
     * DO NOT dispose the controller here.
     */
    Navigator.of(context).pop(name);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Create New Folder',
      ),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: false,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Folder Name',
          hintText: 'e.g., Medical, Identity, Passports',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) {
          _createFolder();
        },
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text(
            'Cancel',
          ),
        ),
        FilledButton(
          onPressed: _createFolder,
          child: const Text(
            'Create',
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DELETE MEMBER DIALOG
// ============================================================================

class _DeleteMemberDialog extends StatefulWidget {
  final String memberName;

  const _DeleteMemberDialog({
    required this.memberName,
  });

  @override
  State<_DeleteMemberDialog> createState() => _DeleteMemberDialogState();
}

class _DeleteMemberDialogState extends State<_DeleteMemberDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();

    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        _focusNode.requestFocus();
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  bool get _nameMatches {
    return _controller.text.trim() == widget.memberName.trim();
  }

  void _delete() {
    if (!_nameMatches) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Delete Family Member?',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete '
            '${widget.memberName} and all associated '
            'folders and documents.',
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            'Type "${widget.memberName}" to confirm:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Full Name',
            ),
            onChanged: (_) {
              setState(() {});
            },
            onSubmitted: (_) {
              _delete();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(false);
          },
          child: const Text(
            'Cancel',
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: _nameMatches ? _delete : null,
          child: const Text(
            'Delete',
          ),
        ),
      ],
    );
  }
}
