import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/sim/game_calendar.dart';
import 'package:vehicle_manager_bd/core/sim/trip_timing.dart';

import '../../support/sim_support.dart';
import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();

  group('GameCalendar', () {
    final calendar = GameCalendar.fromSettings(config.settings, t0);

    test('a game day is 24 game hours, which is 24 real minutes', () {
      expect(calendar.dayLength, const Duration(minutes: 24));
    });

    test('day length follows gameMinutesPerRealMinute', () {
      final slow = GameCalendar.fromSettings(
        editedConfig(
          (j) => j['settings']['gameMinutesPerRealMinute'] = 30,
        ).settings,
        t0,
      );
      expect(slow.dayLength, const Duration(minutes: 48));
    });

    test('day index changes exactly at the boundary', () {
      expect(calendar.dayIndex(t0), 0);
      expect(
        calendar.dayIndex(t0.add(const Duration(minutes: 23, seconds: 59))),
        0,
      );
      expect(calendar.dayIndex(t0.add(const Duration(minutes: 24))), 1);
      expect(calendar.dayIndex(t0.add(const Duration(minutes: 48))), 2);
    });

    test('days before the anchor are negative', () {
      expect(
        calendar.dayIndex(t0.subtract(const Duration(microseconds: 1))),
        -1,
      );
      expect(calendar.dayIndex(t0.subtract(const Duration(minutes: 24))), -1);
      expect(calendar.dayIndex(t0.subtract(const Duration(minutes: 25))), -2);
    });

    test('next day start', () {
      expect(
        calendar.nextDayStart(t0.add(const Duration(minutes: 10))),
        t0.add(const Duration(minutes: 24)),
      );
      expect(
        calendar.nextDayStart(t0.add(const Duration(minutes: 24))),
        t0.add(const Duration(minutes: 48)),
      );
    });
  });

  group('GameCalendar with a turbo bonus', () {
    GameCalendar withBonus(
      Duration bonus, {
      DateTime? now,
      double turboSpeed = 1,
    }) {
      return GameCalendar.fromSettings(
        config.settings,
        t0,
        bonus: bonus,
        now: now,
        turboSpeed: turboSpeed,
      );
    }

    test('the bonus moves the game clock forward', () {
      final calendar = withBonus(const Duration(minutes: 10));
      expect(calendar.dayIndex(t0), 0);
      expect(calendar.dayIndex(t0.add(const Duration(minutes: 13))), 0);
      expect(calendar.dayIndex(t0.add(const Duration(minutes: 14))), 1);
    });

    test('the full turbo bonus is 26 days and 16 minutes of game clock', () {
      final calendar = withBonus(const Duration(minutes: 640));
      expect(calendar.dayIndex(t0), 26);
    });

    test('day start and day index agree', () {
      final calendar = withBonus(const Duration(minutes: 10));
      final start = calendar.dayStart(1);
      expect(start, t0.add(const Duration(minutes: 14)));
      expect(calendar.dayIndex(start), 1);
      expect(
        calendar.dayIndex(start.subtract(const Duration(microseconds: 1))),
        0,
      );
    });

    test('with no turbo ahead the next day start is the exact boundary', () {
      final calendar = withBonus(
        const Duration(minutes: 10),
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(
        calendar.nextDayStart(t0.add(const Duration(minutes: 5))),
        t0.add(const Duration(minutes: 14)),
      );
    });

    test('a boundary ahead arrives turboSpeed times sooner', () {
      // The game clock reads 5 min of the 24 minute day: 19 game minutes left,
      // which take 19 / 20 = 0.95 real minutes at 20x.
      final now = t0.add(const Duration(minutes: 5));
      final calendar = withBonus(Duration.zero, now: now, turboSpeed: 20);
      expect(calendar.nextDayStart(now), now.add(const Duration(seconds: 57)));
    });

    test('a boundary already behind now is not pulled closer', () {
      final now = t0.add(const Duration(minutes: 40));
      final calendar = withBonus(Duration.zero, now: now, turboSpeed: 20);
      final earlier = t0.add(const Duration(minutes: 10));
      expect(
        calendar.nextDayStart(earlier),
        t0.add(const Duration(minutes: 24)),
      );
    });

    test('the projected boundary is never at or before the start time', () {
      final now = t0.add(const Duration(minutes: 23, seconds: 59));
      final calendar = withBonus(Duration.zero, now: now, turboSpeed: 20);
      expect(calendar.nextDayStart(now).isAfter(now), true);
    });

    test('waking at the projected instant lands in the next day', () {
      final now = t0.add(const Duration(minutes: 5));
      final calendar = withBonus(Duration.zero, now: now, turboSpeed: 20);
      final wake = calendar.nextDayStart(now);
      // Foreground turbo went on: the bonus gained 19 for each real minute.
      final gained = Duration(
        microseconds: (wake.difference(now).inMicroseconds * 19),
      );
      final later = withBonus(gained);
      expect(later.dayIndex(wake), 1);
    });
  });

  group('realTripDuration', () {
    final settings = config.settings;

    test('1 game hour is 1 real minute at 1x', () {
      expect(
        realTripDuration(settings: settings, gameHours: 1, turboSpeed: 1),
        const Duration(minutes: 1),
      );
    });

    test('Tier 6 on R05 (9.25 game hours) takes 9 min 15 s at 1x', () {
      expect(
        realTripDuration(settings: settings, gameHours: 9.25, turboSpeed: 1),
        const Duration(minutes: 9, seconds: 15),
      );
    });

    test('turbo divides the duration', () {
      expect(
        realTripDuration(settings: settings, gameHours: 9.25, turboSpeed: 20),
        const Duration(seconds: 27, milliseconds: 750),
      );
      expect(
        realTripDuration(settings: settings, gameHours: 9.25, turboSpeed: 5),
        const Duration(minutes: 1, seconds: 51),
      );
    });

    test('uses gameMinutesPerRealMinute', () {
      final fast = editedConfig(
        (j) => j['settings']['gameMinutesPerRealMinute'] = 120,
      ).settings;
      expect(
        realTripDuration(settings: fast, gameHours: 2, turboSpeed: 1),
        const Duration(minutes: 1),
      );
    });
  });
}
