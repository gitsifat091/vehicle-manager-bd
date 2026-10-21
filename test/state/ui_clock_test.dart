import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/state/ui_clock.dart';

import '../support/sim_support.dart';

Future<void> settle([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ManualClock clock;
  late UiClock ui;
  var notifications = 0;

  setUp(() {
    clock = ManualClock();
    notifications = 0;
    ui = UiClock(clock, interval: const Duration(milliseconds: 20))
      ..addListener(() => notifications++);
  });

  tearDown(() => ui.dispose());

  test('starts at the clock\'s now', () {
    expect(ui.now, t0);
    expect(ui.isRunning, false);
  });

  test(
    'looks at the clock again on every interval and tells its listeners',
    () async {
      ui.start();
      final afterStart = notifications;
      clock.advance(const Duration(minutes: 5));
      await settle(70);
      expect(ui.now, t0.add(const Duration(minutes: 5)));
      expect(notifications - afterStart, greaterThanOrEqualTo(2));
    },
  );

  test('stop ends the ticking', () async {
    ui.start();
    await settle(50);
    ui.stop();
    final count = notifications;
    await settle(70);
    expect(notifications, count);
    expect(ui.isRunning, false);
  });

  test('starting twice keeps one timer', () async {
    ui.start();
    ui.start();
    await settle(110);
    // One immediate refresh plus about 5 ticks, not twice that.
    expect(notifications, lessThan(9));
  });

  test('hidden stops it, resumed catches up at once', () async {
    ui.start();
    ui.didChangeAppLifecycleState(AppLifecycleState.hidden);
    final count = notifications;
    clock.advance(const Duration(hours: 1));
    await settle(70);
    expect(notifications, count);
    expect(ui.now, t0);

    ui.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(ui.now, t0.add(const Duration(hours: 1)));
    expect(notifications, count + 1);
    await settle(50);
    expect(notifications, greaterThan(count + 1));
  });

  test('a window that only lost focus keeps ticking', () async {
    ui.start();
    ui.didChangeAppLifecycleState(AppLifecycleState.inactive);
    final count = notifications;
    await settle(70);
    expect(notifications, greaterThan(count));
  });

  test('lifecycle changes are ignored when it is not running', () async {
    ui.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle(60);
    expect(notifications, 0);
  });
}
