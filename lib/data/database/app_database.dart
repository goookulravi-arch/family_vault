import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class FamilyMembers extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get relationship => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get profileImagePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomFields extends Table {
  TextColumn get id => text()();
  TextColumn get memberId =>
      text().references(FamilyMembers, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldName => text()();
  TextColumn get fieldValue => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get memberId =>
      text().references(FamilyMembers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get memberId =>
      text().references(FamilyMembers, #id, onDelete: KeyAction.cascade)();
  TextColumn get folderId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [FamilyMembers, CustomFields, Folders, Documents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'family_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
