import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_manager_bd/app.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';

import 'core/test_config.dart';
import 'data/save_test_helper.dart';
import 'support/sim_support.dart';

/// Counts what the app's loop asks of the engine, without touching the disk.
class CountingEngine extends GameEngine {
  CountingEngine({required super.config, required super.database})
    : super(clock: ManualClock());

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

void main() {
  final folder = SaveFolder()..register();
  final config = loadDefaultConfig();
  late SaveDatabase db;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  /// Opens the temp save and starts a game, outside the fake-async zone.
  Future<GameEngine> engineWithGame(WidgetTester tester, String name) async {
    late GameEngine engine;
    await tester.runAsync(() async {
      db = await folder.open();
      engine = GameEngine(config: config, database: db, clock: ManualClock());
      await engine.startNewGame(name);
    });
    addTearDown(engine.dispose);
    return engine;
  }

  testWidgets('shows the company from the engine it was given', (tester) async {
    final engine = await engineWithGame(tester, 'Sifat Ltd');
    await tester.pumpWidget(VehicleManagerApp(config: config, engine: engine));

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.text('Sifat Ltd'), findsOneWidget);
    expect(find.text('Tk 1500000'), findsOneWidget);
    expect(find.text('Turbo 20x'), findsOneWidget);
  });

  testWidgets('without a game it says so', (tester) async {
    await tester.runAsync(() async => db = await folder.open());
    final engine = GameEngine(config: config, database: db, clock: ManualClock());
    addTearDown(engine.dispose);
    await tester.pumpWidget(VehicleManagerApp(config: config, engine: engine));
    expect(find.text('No game yet'), findsOneWidget);
  });

  testWidgets('rebuilds when the engine notifies', (tester) async {
    final engine = await engineWithGame(tester, 'First');
    await tester.pumpWidget(VehicleManagerApp(config: config, engine: engine));
    expect(find.text('First'), findsOneWidget);

    await tester.runAsync(() => engine.startNewGame('Second'));
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('puts the config and the engine in the widget tree', (
    tester,
  ) async {
    final engine = await engineWithGame(tester, 'A');
    await tester.pumpWidget(VehicleManagerApp(config: config, engine: engine));

    final context = tester.element(find.byType(PlaceholderScreen));
    expect(Provider.of<GameEngine>(context, listen: false), same(engine));
    expect(Provider.of<EconomyConfig>(context, listen: false), same(config));
  });

  group('the game loop', () {
    late CountingEngine engine;

    setUp(() async {
      db = await folder.open();
      engine = CountingEngine(config: config, database: db);
    });

    tearDown(() => engine.dispose());

    Widget app() => VehicleManagerApp(
      config: config,
      engine: engine,
      loopInterval: const Duration(milliseconds: 20),
    );

    testWidgets('ticks while the app lives and stops when it is removed', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 105));
      expect(engine.ticks, greaterThanOrEqualTo(4));

      await tester.pumpWidget(const SizedBox());
      final ticks = engine.ticks;
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.ticks, ticks);
    });

    testWidgets('hiding the window pauses, coming back resumes', (tester) async {
      await tester.pumpWidget(app());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(engine.pauses, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(engine.resumes, 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a window that only lost focus does not pause', (tester) async {
      await tester.pumpWidget(app());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.pauses, 0);
      expect(engine.ticks, greaterThanOrEqualTo(3));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
