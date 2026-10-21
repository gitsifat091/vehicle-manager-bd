import 'package:hive_ce/hive_ce.dart';

/// Keyed storage for one model type, backed by a Hive box.
///
/// Reads come straight from memory (Hive keeps the box loaded). Writes
/// complete when the data is on disk.
abstract class BoxRepository<T> {
  BoxRepository(this.box);

  final Box<T> box;

  /// The unique key for [item].
  String keyOf(T item);

  int get count => box.length;

  T? get(String key) => box.get(key);

  List<T> all() => box.values.toList();

  Future<void> put(T item) => box.put(keyOf(item), item);

  Future<void> putAll(Iterable<T> items) {
    return box.putAll({for (final item in items) keyOf(item): item});
  }

  Future<void> delete(String key) => box.delete(key);

  Future<void> clear() => box.clear();
}
