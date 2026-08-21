import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../../features/family_members/models/family_member_with_counts.dart';

class FamilyMemberRepository {
  final AppDatabase db;

  final _uuid = const Uuid();

  FamilyMemberRepository(this.db);

  // ============================================================
  // FAMILY MEMBER METHODS
  // ============================================================

  Future<FamilyMember?> getMemberById(
    String memberId,
  ) async {
    return (db.select(db.familyMembers)
          ..where(
            (m) => m.id.equals(memberId),
          ))
        .getSingleOrNull();
  }

  Future<void> addFamilyMember({
    required FamilyMembersCompanion member,
    List<CustomFieldsCompanion>? customFields,
  }) async {
    await db.transaction(() async {
      await db.into(db.familyMembers).insert(member);

      if (customFields != null && customFields.isNotEmpty) {
        for (final field in customFields) {
          await db.into(db.customFields).insert(field);
        }
      }
    });
  }

  Future<void> updateFamilyMember({
    String? id,
    required FamilyMembersCompanion member,
    List<CustomFieldsCompanion>? customFields,
  }) async {
    final memberId = id ?? member.id.value;

    await db.transaction(() async {
      await (db.update(db.familyMembers)
            ..where(
              (m) => m.id.equals(memberId),
            ))
          .write(member);

      if (customFields != null) {
        await (db.delete(db.customFields)
              ..where(
                (c) => c.memberId.equals(memberId),
              ))
            .go();

        for (final field in customFields) {
          await db.into(db.customFields).insert(field);
        }
      }
    });
  }

  // ============================================================
  // DELETE FAMILY MEMBER
  //
  // Deletes:
  // - Custom fields
  // - Documents
  // - Folders
  // - Family member
  // - Physical document files
  // ============================================================

  Future<void> deleteFamilyMember(
    String memberId,
  ) async {
    final documents = await (db.select(db.documents)
          ..where(
            (d) => d.memberId.equals(memberId),
          ))
        .get();

    await db.transaction(() async {
      // Delete custom fields.
      await (db.delete(db.customFields)
            ..where(
              (c) => c.memberId.equals(memberId),
            ))
          .go();

      // Delete documents.
      await (db.delete(db.documents)
            ..where(
              (d) => d.memberId.equals(memberId),
            ))
          .go();

      // Delete folders.
      await (db.delete(db.folders)
            ..where(
              (f) => f.memberId.equals(memberId),
            ))
          .go();

      // Delete member.
      await (db.delete(db.familyMembers)
            ..where(
              (m) => m.id.equals(memberId),
            ))
          .go();
    });

    // Delete physical document files.
    for (final document in documents) {
      try {
        final file = File(document.filePath);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Database deletion already succeeded.
      }
    }
  }

  // ============================================================
  // ONE-TIME ORPHANED DATA CLEANUP
  //
  // This removes old folders/documents that belong to members
  // that no longer exist in the FamilyMembers table.
  //
  // USE ONCE ONLY.
  // ============================================================

  Future<void> cleanupOrphanedData() async {
    // ----------------------------------------------------------
    // Get all existing family members.
    // ----------------------------------------------------------

    final members = await db.select(db.familyMembers).get();

    final validMemberIds = members
        .map(
          (member) => member.id,
        )
        .toSet();

    // ----------------------------------------------------------
    // Get all folders.
    // ----------------------------------------------------------

    final folders = await db.select(db.folders).get();

    // ----------------------------------------------------------
    // Get all documents.
    // ----------------------------------------------------------

    final documents = await db.select(db.documents).get();

    // ----------------------------------------------------------
    // Find orphaned folders.
    // ----------------------------------------------------------

    final orphanFolders = folders.where(
      (folder) => !validMemberIds.contains(folder.memberId),
    );

    // ----------------------------------------------------------
    // Find orphaned documents.
    // ----------------------------------------------------------

    final orphanDocuments = documents.where(
      (document) => !validMemberIds.contains(document.memberId),
    );

    // Save physical file paths before deleting DB records.
    final filesToDelete = orphanDocuments
        .map(
          (document) => document.filePath,
        )
        .toList();

    // ----------------------------------------------------------
    // Find orphaned custom fields.
    // ----------------------------------------------------------

    final customFields = await db.select(db.customFields).get();

    final orphanCustomFields = customFields.where(
      (field) => !validMemberIds.contains(field.memberId),
    );

    // ----------------------------------------------------------
    // Delete database records.
    // ----------------------------------------------------------

    await db.transaction(() async {
      // Delete orphan documents first.
      for (final document in orphanDocuments) {
        await (db.delete(db.documents)
              ..where(
                (d) => d.id.equals(document.id),
              ))
            .go();
      }

      // Delete orphan folders.
      for (final folder in orphanFolders) {
        await (db.delete(db.folders)
              ..where(
                (f) => f.id.equals(folder.id),
              ))
            .go();
      }

      // Delete orphan custom fields.
      for (final field in orphanCustomFields) {
        await (db.delete(db.customFields)
              ..where(
                (c) => c.id.equals(field.id),
              ))
            .go();
      }
    });

    // ----------------------------------------------------------
    // Delete physical document files.
    // ----------------------------------------------------------

    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore individual file deletion failures.
      }
    }
  }

  // ============================================================
  // CUSTOM FIELD METHODS
  // ============================================================

  Future<List<CustomField>> getCustomFieldsForMember(
    String memberId,
  ) async {
    return (db.select(db.customFields)
          ..where(
            (c) => c.memberId.equals(memberId),
          ))
        .get();
  }

  // ============================================================
  // FOLDER METHODS
  // ============================================================

  Future<Folder?> getFolderById(
    String folderId,
  ) async {
    return (db.select(db.folders)
          ..where(
            (f) => f.id.equals(folderId),
          ))
        .getSingleOrNull();
  }

  Future<List<Folder>> getFoldersForMember(
    String memberId,
  ) async {
    return (db.select(db.folders)
          ..where(
            (f) => f.memberId.equals(memberId),
          )
          ..orderBy([
            (f) => OrderingTerm(
                  expression: f.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<void> createFolder({
    required String memberId,
    required String name,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Folder name cannot be empty.',
      );
    }

    await db.into(db.folders).insert(
          FoldersCompanion.insert(
            id: _uuid.v4(),
            memberId: memberId,
            name: trimmedName,
          ),
        );
  }

  // ============================================================
  // RENAME FOLDER
  // ============================================================

  Future<void> renameFolder({
    required String folderId,
    required String newName,
  }) async {
    final trimmedName = newName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Folder name cannot be empty.',
      );
    }

    await (db.update(db.folders)
          ..where(
            (f) => f.id.equals(folderId),
          ))
        .write(
      FoldersCompanion(
        name: Value(trimmedName),
      ),
    );
  }

  // ============================================================
  // DELETE FOLDER
  // ============================================================

  Future<void> deleteFolder(
    String folderId,
  ) async {
    final documents = await getDocumentsInFolder(
      folderId,
    );

    await db.transaction(() async {
      // Delete documents.
      await (db.delete(db.documents)
            ..where(
              (d) => d.folderId.equals(folderId),
            ))
          .go();

      // Delete folder.
      await (db.delete(db.folders)
            ..where(
              (f) => f.id.equals(folderId),
            ))
          .go();
    });

    // Delete physical files.
    for (final document in documents) {
      try {
        final file = File(document.filePath);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Database deletion already succeeded.
      }
    }
  }

  // ============================================================
  // DOCUMENT METHODS
  // ============================================================

  Future<List<Document>> getDocumentsInFolder(
    String folderId,
  ) async {
    return (db.select(db.documents)
          ..where(
            (d) => d.folderId.equals(folderId),
          )
          ..orderBy([
            (d) => OrderingTerm(
                  expression: d.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // WATCH DOCUMENTS IN FOLDER
  //
  // Automatically updates when:
  // - Document is uploaded
  // - Document is renamed
  // - Document is deleted
  // ============================================================

  Stream<List<Document>> watchDocumentsInFolder(
    String folderId,
  ) {
    return (db.select(db.documents)
          ..where(
            (d) => d.folderId.equals(folderId),
          )
          ..orderBy([
            (d) => OrderingTerm(
                  expression: d.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  // ============================================================
  // ROOT DOCUMENTS
  // ============================================================

  Future<List<Document>> getRootDocumentsForMember(
    String memberId,
  ) async {
    return (db.select(db.documents)
          ..where(
            (d) => d.memberId.equals(memberId) & d.folderId.isNull(),
          )
          ..orderBy([
            (d) => OrderingTerm(
                  expression: d.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // GET DOCUMENT BY ID
  // ============================================================

  Future<Document?> getDocumentById(
    String documentId,
  ) async {
    return (db.select(db.documents)
          ..where(
            (d) => d.id.equals(documentId),
          ))
        .getSingleOrNull();
  }

  // ============================================================
  // ADD DOCUMENT
  // ============================================================

  Future<void> addDocument({
    required String memberId,
    String? folderId,
    required String name,
    required String filePath,
    required String fileType,
    required int fileSize,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Document name cannot be empty.',
      );
    }

    await db.into(db.documents).insert(
          DocumentsCompanion.insert(
            id: _uuid.v4(),
            memberId: memberId,
            folderId: Value(folderId),
            name: trimmedName,
            filePath: filePath,
            fileType: fileType,
            fileSize: fileSize,
          ),
        );
  }

  // ============================================================
  // RENAME DOCUMENT
  // ============================================================

  Future<void> renameDocument({
    required String documentId,
    required String newName,
  }) async {
    final trimmedName = newName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Document name cannot be empty.',
      );
    }

    await (db.update(db.documents)
          ..where(
            (d) => d.id.equals(documentId),
          ))
        .write(
      DocumentsCompanion(
        name: Value(trimmedName),
      ),
    );
  }

  // ============================================================
  // DELETE DOCUMENT
  // ============================================================

  Future<void> deleteDocument(
    String documentId,
  ) async {
    final document = await getDocumentById(documentId);

    if (document == null) {
      return;
    }

    await (db.delete(db.documents)
          ..where(
            (d) => d.id.equals(documentId),
          ))
        .go();

    try {
      final file = File(document.filePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Database record has already been removed.
    }
  }

  // ============================================================
  // FAMILY MEMBER STREAM
  // ============================================================

  Stream<List<FamilyMemberWithCounts>> watchAllMembersWithCounts() {
    return db.select(db.familyMembers).watch().asyncMap(
      (members) async {
        final List<FamilyMemberWithCounts> result = [];

        for (final member in members) {
          final documents = await (db.select(
            db.documents,
          )..where(
                  (d) => d.memberId.equals(
                    member.id,
                  ),
                ))
              .get();

          final folders = await (db.select(
            db.folders,
          )..where(
                  (f) => f.memberId.equals(
                    member.id,
                  ),
                ))
              .get();

          result.add(
            FamilyMemberWithCounts(
              member: member,
              documentCount: documents.length,
              folderCount: folders.length,
            ),
          );
        }

        return result;
      },
    );
  }
}
