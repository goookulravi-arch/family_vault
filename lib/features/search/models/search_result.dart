import 'package:family_vault/data/database/app_database.dart';

enum SearchResultType {
  member,
  folder,
  document,
}

class SearchResult {
  final SearchResultType type;

  final String id;
  final String title;
  final String subtitle;

  final String? memberId;
  final String? folderId;

  final FamilyMember? member;
  final Folder? folder;
  final Document? document;

  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.memberId,
    this.folderId,
    this.member,
    this.folder,
    this.document,
  });
}
