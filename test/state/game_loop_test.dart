import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';
import 'package:vehicle_manager_bd/state/game_loop.dart';

/// Counts what the loop asks of the engine.
class FakeEngine extends Fake implements GameEngine {
  int ticks = 0;
  int pauses = 0;
  int resumes = 0;

  @override
  Future<void> tick() async => ticks++;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;
}

Future<void> settle([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late GameLoop loop;

  setUp(() {
    engine = FakeEngine();
    loop = GameLoop(engine, interval: const Duration(milliseconds: 20));
  });

  tearDown(() => loop.stop());

  test('ticks on a timer, not on every frame', () async {
    loop.start();
    expect(loop.isRunning, true);
    await settle(130);
    expect(engine.ticks, inInclusiveRange(3, 8));
  });

  test('stop ends the ticking', () async {
    loop.start();
    await settle(70);
    loop.stop();
    final ticks = engine.ticks;
    await settle(80);
    expect(engine.ticks, ticks);
    expect(loop.isRunning, false);
  });

  test('starting twice keeps one timer', () async {
    loop.start();
    loop.start();
    await settle(130);
    expect(engine.ticks, lessThan(10));
  });

  test(
    'going to the background freezes the engine and stops the timer',
    () async {
      loop.start();
      await settle(50);
      loop.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(engine.pauses, 1);
      final ticks = engine.ticks;
      await settle(80);
      expect(engine.ticks, ticks);
    },
  );

  test(
    'coming back resumes the engine, ticks at once and restarts the timer',
    () async {
      loop.start();
      loop.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle(30);
      final before = engine.ticks;

      loop.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(engine.resumes, 1);
      expect(engine.ticks, before + 1, reason: 'one immediate catch-up tick');

      await settle(90);
      expect(engine.ticks, greaterThan(before + 2));
    },
  );

  test('hidden and detached count as background, inactive does not', () async {
    loop.start();
    loop.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await settle();
    expect(engine.pauses, 0);

    loop.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await settle();
    expect(engine.pauses, 1);

    loop.didChangeAppLifecycleState(AppLifecycleState.detached);
    await settle();
    expect(engine.pauses, 2);
  });

  test('lifecycle changes are ignored after stop', () async {
    loop.start();
    loop.stop();
    loop.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle(60);
    expect(engine.resumes, 0);
    expect(engine.ticks, 0);
  });
}
