/// The source of "now" for everything in lib/core.
///
/// Code in lib/core never calls DateTime.now(). It asks a Clock, so tests can
/// move time by hand. The real clock lives in lib/platform/system_clock.dart.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime now();
}
