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
