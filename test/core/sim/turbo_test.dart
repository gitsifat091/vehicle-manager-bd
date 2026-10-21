import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/sim/turbo.dart';

import '../../support/sim_support.dart';
import '../test_config.dart';

void main() {
  final schedule = TurboSchedule.fromSettings(loadDefaultConfig().settings);

  group('TurboSchedule', () {
    test('reads the three phases from the config', () {
      expect(schedule.phases, hasLength(3));
      expect(schedule.total, const Duration(minutes: 60));
    });

    test('speed by foreground time', () {
      expect(schedule.speedAt(Duration.zero), 20);
      expect(schedule.speedAt(const Duration(minutes: 19, seconds: 59)), 20);
      expect(schedule.speedAt(const Duration(minutes: 20)), 10);
      expect(schedule.speedAt(const Duration(minutes: 39, seconds: 59)), 10);
      expect(schedule.speedAt(const Duration(minutes: 40)), 5);
      expect(schedule.speedAt(const Duration(minutes: 59, seconds: 59)), 5);
      expect(schedule.speedAt(const Duration(minutes: 60)), 1);
      expect(schedule.speedAt(const Duration(days: 3)), 1);
    });

    test('is active only before the end', () {
      expect(schedule.isActiveAt(const Duration(minutes: 59)), true);
      expect(schedule.isActiveAt(const Duration(minutes: 60)), false);
    });

    test('phases follow the config values', () {
      final custom = TurboSchedule.fromSettings(
        editedConfig((j) {
          j['settings']['turboPhase1Speed'] = 8;
          j['settings']['turboPhase1EndMin'] = 5;
        }).settings,
      );
      expect(custom.speedAt(const Duration(minutes: 4)), 8);
      expect(custom.speedAt(const Duration(minutes: 5)), 10);
    });
  });

  group('TurboClock', () {
    late ManualClock clock;
    late TurboClock turbo;

    setUp(() {
      clock = ManualClock();
      turbo = TurboClock(schedule: schedule, clock: clock);
    });

    test('does not count before the app is in the foreground', () {
      clock.advance(const Duration(minutes: 30));
      expect(turbo.elapsed, Duration.zero);
      expect(turbo.speed, 20);
      expect(turbo.isForeground, false);
    });

    test('counts foreground time and moves through the phases', () {
      turbo.resume();
      clock.advance(const Duration(minutes: 19));
      expect(turbo.speed, 20);
      clock.advance(const Duration(minutes: 1));
      expect(turbo.elapsed, const Duration(minutes: 20));
      expect(turbo.speed, 10);
      clock.advance(const Duration(minutes: 20));
      expect(turbo.speed, 5);
      clock.advance(const Duration(minutes: 20));
      expect(turbo.speed, 1);
    });

    test('freezes while paused and returns the value to save', () {
      turbo.resume();
      clock.advance(const Duration(minutes: 5));
      final saved = turbo.pause();
      expect(saved, const Duration(minutes: 5));

      clock.advance(const Duration(hours: 8));
      expect(turbo.elapsed, const Duration(minutes: 5));
      expect(turbo.speed, 20);
      expect(turbo.isForeground, false);
    });

    test('continues from the frozen value after resume', () {
      turbo.resume();
      clock.advance(const Duration(minutes: 15));
      turbo.pause();
      clock.advance(const Duration(hours: 2));
      turbo.resume();
      expect(turbo.elapsed, const Duration(minutes: 15));
      clock.advance(const Duration(minutes: 5));
      expect(turbo.elapsed, const Duration(minutes: 20));
      expect(turbo.speed, 10);
    });

    test('starts from a saved accumulated value', () {
      turbo = TurboClock(
        schedule: schedule,
        clock: clock,
        accumulated: const Duration(minutes: 39),
      );
      turbo.resume();
      expect(turbo.speed, 10);
      clock.advance(const Duration(minutes: 1));
      expect(turbo.speed, 5);
    });

    test('resume twice and pause twice change nothing', () {
      turbo.resume();
      clock.advance(const Duration(minutes: 2));
      turbo.resume();
      clock.advance(const Duration(minutes: 2));
      expect(turbo.elapsed, const Duration(minutes: 4));

      expect(turbo.pause(), const Duration(minutes: 4));
      clock.advance(const Duration(minutes: 9));
      expect(turbo.pause(), const Duration(minutes: 4));
    });

    test('a clock that jumps backwards does not subtract time', () {
      turbo.resume();
      clock.advance(const Duration(minutes: 3));
      expect(turbo.pause(), const Duration(minutes: 3));
      turbo.resume();
      clock.advance(const Duration(minutes: -10));
      expect(turbo.elapsed, const Duration(minutes: 3));
    });
  });
}
