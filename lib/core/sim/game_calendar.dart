import '../config/economy_config.dart';

/// Game days. One game day is 24 game hours, which is
/// 24 x 60 / gameMinutesPerRealMinute minutes of game clock (24 by default).
///
/// The game clock is real time since the anchor (the company's creation) plus
/// [bonus], the extra time earned by Turbo Start (see
/// `TurboSchedule.bonusAt`). So days, and the demand resets that go with them,
/// run faster during the turbo, just like trips.
///
/// [bonus] is a single value for the moment of the calculation. Times in the
/// past are read with it too, which is exact for time spent in the background
/// (the bonus does not grow there) and off by a few seconds for the last tick
/// of foreground play. Anything that must remember a day (the demand of a
/// route) therefore stores the day number, not just a timestamp.
class GameCalendar {
  GameCalendar({
    required DateTime anchor,
    required this.dayLength,
    this.bonus = Duration.zero,
    DateTime? now,
    this.turboSpeed = 1,
  }) : anchor = anchor.toUtc(),
       now = now?.toUtc();

  /// [now] and [turboSpeed] let [nextDayStart] know that a day boundary still
  /// ahead will arrive [turboSpeed] times faster in real time.
  factory GameCalendar.fromSettings(
    EconomySettings s,
    DateTime anchor, {
    Duration bonus = Duration.zero,
    DateTime? now,
    double turboSpeed = 1,
  }) {
    final minutes = 24 * 60 / s.gameMinutesPerRealMinute;
    return GameCalendar(
      anchor: anchor,
      dayLength: Duration(microseconds: (minutes * 60e6).round()),
      bonus: bonus,
      now: now,
      turboSpeed: turboSpeed,
    );
  }

  final DateTime anchor;
  final Duration dayLength;

  /// Turbo time added to the game clock.
  final Duration bonus;

  /// The present moment, when known. Only [nextDayStart] uses it.
  final DateTime? now;

  /// The turbo speed from [now] on. 1 when the turbo is over.
  final double turboSpeed;

  /// Which game day [t] falls in. Day 0 starts at the anchor.
  int dayIndex(DateTime t) {
    final micros = t.difference(anchor).inMicroseconds + bonus.inMicroseconds;
    final length = dayLength.inMicroseconds;
    return (micros - (micros % length)) ~/ length;
  }

  /// The real instant the game clock reaches the start of day [index], if the
  /// bonus stays as it is.
  DateTime dayStart(int index) => anchor.add(dayLength * index - bonus);

  /// The real instant of the first game day after the one containing [t].
  ///
  /// A boundary that is already behind [now] is exact. One still ahead is
  /// pulled closer by [turboSpeed], assuming the app stays in the foreground.
  /// If it does not, the caller wakes up a little early, finds the same day
  /// and waits again.
  DateTime nextDayStart(DateTime t) {
    final boundary = dayStart(dayIndex(t) + 1);
    final from = now;
    if (from == null || turboSpeed <= 1 || !boundary.isAfter(from)) {
      return boundary;
    }
    final ahead = boundary.difference(from).inMicroseconds;
    return from.add(Duration(microseconds: (ahead / turboSpeed).ceil()));
  }
}
