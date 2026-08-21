import 'package:drift/drift.dart';
import 'family_members.dart';

class CustomFields extends Table {
  TextColumn get id => text()();
  TextColumn get familyMemberId =>
      text().references(FamilyMembers, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldName => text()();
  TextColumn get fieldValue => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
