import '../config/economy_config.dart';

/// Game days. One game day is 24 game hours, which is
/// 24 x 60 / gameMinutesPerRealMinute real minutes (24 minutes by default).
///
/// Days run on real time from an anchor (the company's creation). Turbo Start
/// does not stretch them: it only makes trips faster.
class GameCalendar {
  GameCalendar({required DateTime anchor, required this.dayLength})
    : anchor = anchor.toUtc();

  factory GameCalendar.fromSettings(EconomySettings s, DateTime anchor) {
    final minutes = 24 * 60 / s.gameMinutesPerRealMinute;
    return GameCalendar(
      anchor: anchor,
      dayLength: Duration(microseconds: (minutes * 60e6).round()),
    );
  }

  final DateTime anchor;
  final Duration dayLength;

  /// Which game day [t] falls in. Day 0 starts at the anchor.
  int dayIndex(DateTime t) {
    final micros = t.difference(anchor).inMicroseconds;
    final length = dayLength.inMicroseconds;
    return (micros - (micros % length)) ~/ length;
  }

  DateTime dayStart(int index) => anchor.add(dayLength * index);

  /// The first instant of the game day after the one containing [t].
  DateTime nextDayStart(DateTime t) => dayStart(dayIndex(t) + 1);
}
