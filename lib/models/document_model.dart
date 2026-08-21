class DocumentModel {
  final String id;
  final String memberId;
  final String? folderId; // null if stored in root member folder
  final String name;
  final String filePath;
  final String fileType; // pdf, image, doc, etc.
  final int fileSize; // in bytes
  final DateTime uploadedAt;

  DocumentModel({
    required this.id,
    required this.memberId,
    this.folderId,
    required this.name,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
  });
}
