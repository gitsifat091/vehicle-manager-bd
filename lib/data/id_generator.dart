import 'dart:math';

final Random _secureRandom = Random.secure();

/// [newId] stamped with a given time, for callers that hold a clock.
String newIdAt(String prefix, DateTime now) => newId(prefix, now: now);

/// A short unique id such as `veh_lq3x9k2a7f4c`: the prefix, the time in
/// base 36, then random base 36 digits. No package needed for one local save.
String newId(String prefix, {DateTime? now, Random? random}) {
  final time = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final rng = random ?? _secureRandom;
  final suffix = List.generate(6, (_) => rng.nextInt(36).toRadixString(36));
  return '${prefix}_${time.toRadixString(36)}${suffix.join()}';
}
