import 'package:hive_ce/hive_ce.dart';

/// Type ids for the hand-written adapters. Never reuse or renumber one: a
/// saved file stores the id next to every value.
abstract final class HiveTypeIds {
  static const company = 0;
  static const vehicle = 1;
  static const terminal = 2;
  static const routeState = 3;
  static const trip = 4;
  static const tripCosts = 5;
  static const changeSet = 6;
  static const dayRollup = 7;
}

/// Every adapter writes the field count, then (index, value) pairs. This is
/// the layout Hive's own generator uses. It lets a newer build add a field
/// with a fresh index and still read an older save: the new field is simply
/// absent and the adapter falls back to a default.
///
/// Rules for editing an adapter:
/// - never change or reuse the index of an existing field
/// - give every new field a default for saves that lack it
void writeFields(BinaryWriter writer, Map<int, Object?> fields) {
  writer.writeByte(fields.length);
  fields.forEach((index, value) {
    writer.writeByte(index);
    writer.write(value);
  });
}

/// Reads what [writeFields] wrote.
Map<int, Object?> readFields(BinaryReader reader) {
  final count = reader.readByte();
  return {for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
}

/// Instants are stored as UTC milliseconds since the epoch, as plain ints, so
/// they come back as the same UTC instant on every platform.
int encodeInstant(DateTime instant) => instant.millisecondsSinceEpoch;

DateTime decodeInstant(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
