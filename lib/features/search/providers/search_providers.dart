import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family_members/providers/family_member_providers.dart';
import '../models/search_result.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) {
    return [];
  }

  final repository = ref.read(
    familyMemberRepositoryProvider,
  );

  final database = ref.read(
    databaseProvider,
  );

  final results = <SearchResult>[];

  // ============================================================
  // LOAD FAMILY MEMBERS
  // ============================================================

  final members = await database
      .select(
        database.familyMembers,
      )
      .get();

  // ============================================================
  // SEARCH FAMILY MEMBERS
  //
  // Searches:
  // - Full name
  // - Relationship
  // - Phone
  // - Email
  // - Address
  // ============================================================

  for (final member in members) {
    final fullName = member.fullName.toLowerCase();

    final relationship = member.relationship?.toLowerCase() ?? '';

    final phone = member.phone?.toLowerCase() ?? '';

    final email = member.email?.toLowerCase() ?? '';

    final address = member.address?.toLowerCase() ?? '';

    final matches = fullName.contains(query) ||
        relationship.contains(query) ||
        phone.contains(query) ||
        email.contains(query) ||
        address.contains(query);

    if (matches) {
      results.add(
        SearchResult(
          type: SearchResultType.member,
          id: member.id,
          title: member.fullName,
          subtitle: _buildMemberSubtitle(
            member.phone,
            member.email,
          ),
          memberId: member.id,
          member: member,
        ),
      );
    }
  }

  // ============================================================
  // SEARCH FOLDERS
  // ============================================================

  final folders = await database
      .select(
        database.folders,
      )
      .get();

  for (final folder in folders) {
    final folderName = folder.name.toLowerCase();

    if (!folderName.contains(query)) {
      continue;
    }

    final member = await repository.getMemberById(
      folder.memberId,
    );

    results.add(
      SearchResult(
        type: SearchResultType.folder,
        id: folder.id,
        title: folder.name,
        subtitle: member != null ? 'Folder • ${member.fullName}' : 'Folder',
        memberId: folder.memberId,
        folderId: folder.id,
        folder: folder,
      ),
    );
  }

  // ============================================================
  // SEARCH DOCUMENTS
  //
  // Searches:
  // - Document name
  // - File type
  // ============================================================

  final documents = await database
      .select(
        database.documents,
      )
      .get();

  for (final document in documents) {
    final documentName = document.name.toLowerCase();

    final fileType = document.fileType.toLowerCase();

    final matches = documentName.contains(query) || fileType.contains(query);

    if (!matches) {
      continue;
    }

    final member = await repository.getMemberById(
      document.memberId,
    );

    results.add(
      SearchResult(
        type: SearchResultType.document,
        id: document.id,
        title: document.name,
        subtitle: member != null ? 'Document • ${member.fullName}' : 'Document',
        memberId: document.memberId,
        folderId: document.folderId,
        document: document,
      ),
    );
  }

  return results;
});

// ============================================================
// MEMBER SUBTITLE
// ============================================================

String _buildMemberSubtitle(
  String? phone,
  String? email,
) {
  final values = <String>[];

  if (phone != null && phone.trim().isNotEmpty) {
    values.add(phone.trim());
  }

  if (email != null && email.trim().isNotEmpty) {
    values.add(email.trim());
  }

  if (values.isEmpty) {
    return 'Family Member';
  }

  return 'Family Member • '
      '${values.join(' • ')}';
}
