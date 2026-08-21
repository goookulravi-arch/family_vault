import 'package:drift/drift.dart';

class FamilyMembers extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text().withLength(min: 1, max: 100)();
  TextColumn get relationship => text().nullable()();
  TextColumn get profileImagePath => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}