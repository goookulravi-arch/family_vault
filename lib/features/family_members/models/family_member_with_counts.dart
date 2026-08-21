import '../../../data/database/app_database.dart';

class FamilyMemberWithCounts {
  final FamilyMember member;
  final int folderCount;
  final int documentCount;

  FamilyMemberWithCounts({
    required this.member,
    required this.folderCount,
    required this.documentCount,
  });
}
