class FolderModel {
  final String id;
  final String memberId;
  final String name;
  final int fileCount;
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.memberId,
    required this.name,
    this.fileCount = 0,
    required this.createdAt,
  });
}
