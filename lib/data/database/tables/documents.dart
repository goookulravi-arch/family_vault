import 'package:drift/drift.dart';
import 'family_members.dart';
import 'folders.dart';

class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get folderId =>
      text().references(Folders, #id, onDelete: KeyAction.cascade)();
  TextColumn get familyMemberId =>
      text().references(FamilyMembers, #id, onDelete: KeyAction.cascade)();
  TextColumn get fileName => text()();
  TextColumn get originalFileName => text()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get fileSize => integer()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get issueDate => dateTime().nullable()();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
