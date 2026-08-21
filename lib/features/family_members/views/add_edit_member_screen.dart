import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../providers/family_member_providers.dart';

class CustomFieldInput {
  final TextEditingController keyController;
  final TextEditingController valueController;

  CustomFieldInput({
    String key = '',
    String value = '',
  })  : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class AddEditMemberScreen extends ConsumerStatefulWidget {
  final String? memberId;

  const AddEditMemberScreen({
    super.key,
    this.memberId,
  });

  @override
  ConsumerState<AddEditMemberScreen> createState() =>
      _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends ConsumerState<AddEditMemberScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();

  final TextEditingController _relationshipController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  final Uuid _uuid = const Uuid();

  DateTime? _selectedDob;

  String? _selectedGender;

  String? _profileImagePath;

  final List<CustomFieldInput> _customFields = <CustomFieldInput>[];

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isPickingImage = false;

  final List<String> _genderOptions = <String>[
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  bool get _isEditing => widget.memberId != null;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _loadExistingMember();
    } else {
      _isInitializing = false;
    }
  }

  // ============================================================
  // LOAD EXISTING MEMBER
  // ============================================================

  Future<void> _loadExistingMember() async {
    try {
      final repository = ref.read(familyMemberRepositoryProvider);

      final member = await repository.getMemberById(
        widget.memberId!,
      );

      if (member != null) {
        _fullNameController.text = member.fullName;

        _relationshipController.text = member.relationship ?? '';

        _phoneController.text = member.phone ?? '';

        _emailController.text = member.email ?? '';

        _addressController.text = member.address ?? '';

        _notesController.text = member.notes ?? '';

        _selectedDob = member.dateOfBirth;

        _selectedGender = member.gender;

        _profileImagePath = member.profileImagePath;

        final fields = await repository.getCustomFieldsForMember(
          member.id,
        );

        for (final field in fields) {
          _customFields.add(
            CustomFieldInput(
              key: field.fieldName,
              value: field.fieldValue,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load member: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    for (final field in _customFields) {
      field.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // PROFILE PHOTO OPTIONS
  // ============================================================

  Future<void> _showImageOptions() async {
    if (_isPickingImage || _isLoading) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // CAMERA
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                ),
                title: const Text(
                  'Take Photo',
                ),
                onTap: () {
                  Navigator.of(
                    sheetContext,
                  ).pop();

                  _pickImage(
                    ImageSource.camera,
                  );
                },
              ),

              // GALLERY
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                ),
                title: const Text(
                  'Choose from Gallery',
                ),
                onTap: () {
                  Navigator.of(
                    sheetContext,
                  ).pop();

                  _pickImage(
                    ImageSource.gallery,
                  );
                },
              ),

              // REMOVE
              if (_profileImagePath != null && _profileImagePath!.isNotEmpty)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _removeProfileImage();
                  },
                ),

              const SizedBox(
                height: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    if (_isPickingImage || _isLoading) {
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile == null) {
        return;
      }

      final permanentPath = await _copyImageToVault(
        pickedFile,
      );

      if (!mounted) return;

      setState(() {
        _profileImagePath = permanentPath;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to select profile photo: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isPickingImage = false;
      });
    }
  }

  // ============================================================
  // COPY IMAGE TO APP STORAGE
  // ============================================================

  Future<String> _copyImageToVault(
    XFile pickedFile,
  ) async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final profileDirectory = Directory(
      path.join(
        appDirectory.path,
        'profile_images',
      ),
    );

    if (!await profileDirectory.exists()) {
      await profileDirectory.create(
        recursive: true,
      );
    }

    String extension = path
        .extension(
          pickedFile.path,
        )
        .toLowerCase();

    if (extension.isEmpty) {
      extension = '.jpg';
    }

    final fileName = '${_uuid.v4()}$extension';

    final destination = path.join(
      profileDirectory.path,
      fileName,
    );

    final sourceFile = File(pickedFile.path);

    await sourceFile.copy(
      destination,
    );

    return destination;
  }

  // ============================================================
  // REMOVE PHOTO
  // ============================================================

  Future<void> _removeProfileImage() async {
    if (_profileImagePath == null || _profileImagePath!.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Remove Profile Photo?',
          ),
          content: const Text(
            'The profile photo will be removed from this member.',
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
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final oldPath = _profileImagePath;

    setState(() {
      _profileImagePath = null;
    });

    await _deleteOldProfileImage(
      oldPath,
    );
  }

  // ============================================================
  // DELETE STORED PHOTO SAFELY
  // ============================================================

  Future<void> _deleteOldProfileImage(
    String? oldPath,
  ) async {
    if (oldPath == null || oldPath.isEmpty) {
      return;
    }

    try {
      final file = File(oldPath);

      if (!await file.exists()) {
        return;
      }

      final appDirectory = await getApplicationDocumentsDirectory();

      final profileDirectory = path.normalize(
        path.join(
          appDirectory.path,
          'profile_images',
        ),
      );

      final normalizedFilePath = path.normalize(oldPath);

      if (path.isWithin(
            profileDirectory,
            normalizedFilePath,
          ) ||
          normalizedFilePath == profileDirectory) {
        await file.delete();
      }
    } catch (_) {
      // Image cleanup should never prevent
      // the member from being saved.
    }
  }

  // ============================================================
  // PREVIEW PROFILE PHOTO
  // ============================================================

  Future<void> _previewProfileImage() async {
    final imagePath = _profileImagePath;

    if (imagePath == null || imagePath.isEmpty) {
      return;
    }

    final file = File(imagePath);

    if (!await file.exists()) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo is no longer available.',
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: 0.90,
      ),
      builder: (
        BuildContext dialogContext,
      ) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(
            16,
          ),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DATE OF BIRTH
  // ============================================================

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    DateTime initialDate = _selectedDob ??
        DateTime(
          1990,
          1,
          1,
        );

    if (initialDate.isAfter(now)) {
      initialDate = now;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(
        1900,
      ),
      lastDate: now,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDob = picked;
    });
  }

  // ============================================================
  // CUSTOM FIELDS
  // ============================================================

  void _addCustomField() {
    setState(() {
      _customFields.add(
        CustomFieldInput(),
      );
    });
  }

  void _removeCustomField(
    int index,
  ) {
    if (index < 0 || index >= _customFields.length) {
      return;
    }

    final field = _customFields[index];

    setState(() {
      _customFields.removeAt(
        index,
      );
    });

    field.dispose();
  }

  // ============================================================
  // SAVE MEMBER
  // ============================================================

  Future<void> _saveMember() async {
    if (_isLoading) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _isLoading = true;
    });

    String? oldProfileImagePath;

    try {
      final repository = ref.read(
        familyMemberRepositoryProvider,
      );

      final memberId = widget.memberId ?? _uuid.v4();

      // Get old member image before update.
      if (_isEditing) {
        final oldMember = await repository.getMemberById(
          widget.memberId!,
        );

        oldProfileImagePath = oldMember?.profileImagePath;
      }

      final fullName = _fullNameController.text.trim();

      final relationship = _relationshipController.text.trim();

      final phone = _phoneController.text.trim();

      final email = _emailController.text.trim();

      final address = _addressController.text.trim();

      final notes = _notesController.text.trim();

      final member = FamilyMembersCompanion(
        id: Value(
          memberId,
        ),
        fullName: Value(
          fullName,
        ),
        relationship: Value(
          relationship.isEmpty ? null : relationship,
        ),
        dateOfBirth: Value(
          _selectedDob,
        ),
        gender: Value(
          _selectedGender,
        ),
        phone: Value(
          phone.isEmpty ? null : phone,
        ),
        email: Value(
          email.isEmpty ? null : email,
        ),
        address: Value(
          address.isEmpty ? null : address,
        ),
        notes: Value(
          notes.isEmpty ? null : notes,
        ),
        profileImagePath: Value(
          _profileImagePath,
        ),
      );

      final customFields = _customFields
          .where(
        (
          field,
        ) =>
            field.keyController.text.trim().isNotEmpty &&
            field.valueController.text.trim().isNotEmpty,
      )
          .map(
        (
          field,
        ) {
          return CustomFieldsCompanion(
            id: Value(
              _uuid.v4(),
            ),
            memberId: Value(
              memberId,
            ),
            fieldName: Value(
              field.keyController.text.trim(),
            ),
            fieldValue: Value(
              field.valueController.text.trim(),
            ),
          );
        },
      ).toList();

      // ========================================================
      // ADD
      // ========================================================

      if (!_isEditing) {
        await repository.addFamilyMember(
          member: member,
          customFields: customFields,
        );
      }

      // ========================================================
      // UPDATE
      // ========================================================

      else {
        await repository.updateFamilyMember(
          id: widget.memberId,
          member: member,
          customFields: customFields,
        );
      }

      // ========================================================
      // CLEAN OLD IMAGE
      // ========================================================

      if (oldProfileImagePath != null &&
          oldProfileImagePath != _profileImagePath) {
        await _deleteOldProfileImage(
          oldProfileImagePath,
        );
      }

      if (!mounted) return;

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving family member: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // PROFILE PHOTO WIDGET
  // ============================================================

  Widget _buildProfilePhoto() {
    final imagePath = _profileImagePath;

    File? imageFile;

    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);

      if (file.existsSync()) {
        imageFile = file;
      }
    }

    return Center(
      child: Column(
        children: [
          // ======================================================
          // PHOTO
          // ======================================================

          GestureDetector(
            onTap: imageFile != null ? _previewProfileImage : _showImageOptions,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  backgroundImage: imageFile != null
                      ? FileImage(
                          imageFile,
                        )
                      : null,
                  child: imageFile == null
                      ? Icon(
                          Icons.person,
                          size: 58,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary,
                        )
                      : null,
                ),

                // CAMERA BUTTON
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isPickingImage || _isLoading
                          ? null
                          : _showImageOptions,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: _isPickingImage
                            ? const Padding(
                                padding: EdgeInsets.all(
                                  11,
                                ),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // ======================================================
          // PHOTO ACTIONS
          // ======================================================

          if (imageFile == null)
            TextButton.icon(
              onPressed:
                  _isPickingImage || _isLoading ? null : _showImageOptions,
              icon: const Icon(
                Icons.photo_camera,
                size: 18,
              ),
              label: const Text(
                'Add Profile Photo',
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isLoading ? null : _previewProfileImage,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Preview Photo',
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _isPickingImage || _isLoading ? null : _showImageOptions,
                  icon: const Icon(
                    Icons.photo_camera,
                    size: 18,
                  ),
                  label: const Text(
                    'Change Photo',
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _removeProfileImage,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
        ],
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
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit Member' : 'Add Member',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Member' : 'Add Member',
        ),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(
              Icons.check,
            ),
            onPressed: _isLoading ? null : _saveMember,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            // ====================================================
            // PROFILE PHOTO
            // ====================================================

            _buildProfilePhoto(),

            const SizedBox(
              height: 24,
            ),

            // ====================================================
            // FULL NAME
            // ====================================================

            TextFormField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(
                  Icons.person_outline,
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a full name';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // RELATIONSHIP
            // ====================================================

            TextFormField(
              controller: _relationshipController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'e.g. Father, Spouse, Daughter',
                prefixIcon: Icon(
                  Icons.family_restroom,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // DATE OF BIRTH
            // ====================================================

            InkWell(
              onTap: _selectDateOfBirth,
              borderRadius: BorderRadius.circular(
                4,
              ),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: Icon(
                    Icons.cake_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDob == null
                      ? 'Select Date of Birth'
                      : DateFormat(
                          'dd MMMM yyyy',
                        ).format(
                          _selectedDob!,
                        ),
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // GENDER
            // ====================================================

            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(
                  Icons.wc,
                ),
                border: OutlineInputBorder(),
              ),
              items: _genderOptions.map(
                (
                  gender,
                ) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(
                      gender,
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // PHONE
            // ====================================================

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // EMAIL
            // ====================================================

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(
                  Icons.email_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // ADDRESS
            // ====================================================

            TextFormField(
              controller: _addressController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(
                  Icons.home_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // NOTES
            // ====================================================

            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(
                  Icons.note_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ====================================================
            // CUSTOM FIELDS
            // ====================================================

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Custom Fields',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addCustomField,
                  icon: const Icon(
                    Icons.add,
                  ),
                  label: const Text(
                    'Add Field',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            ...List.generate(
              _customFields.length,
              (
                index,
              ) {
                final field = _customFields[index];

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: field.keyController,
                          decoration: const InputDecoration(
                            labelText: 'Field Name',
                            hintText: 'e.g. Blood Group',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: TextField(
                          controller: field.valueController,
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            hintText: 'e.g. O+',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove Field',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeCustomField(
                          index,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(
              height: 24,
            ),

            // ====================================================
            // SAVE BUTTON
            // ====================================================

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveMember,
                icon: const Icon(
                  Icons.save_outlined,
                ),
                label: Text(
                  _isEditing ? 'Update Member' : 'Save Member',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),
          ],
        ),
      ),
    );
  }
}
