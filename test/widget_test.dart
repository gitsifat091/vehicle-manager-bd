import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_manager_bd/app.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';
import 'package:vehicle_manager_bd/state/app_settings.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';
import 'package:vehicle_manager_bd/ui/screens/new_game_screen.dart';
import 'package:vehicle_manager_bd/ui/shell/app_shell.dart';

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
  late AppSettings settings;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget app(GameEngine engine, {Duration? loopInterval}) => VehicleManagerApp(
    config: config,
    engine: engine,
    settings: settings,
    loopInterval: loopInterval ?? const Duration(seconds: 3),
  );

  /// Opens the temp save and starts a game, outside the fake-async zone.
  Future<GameEngine> engineWithGame(
    WidgetTester tester,
    String name, {
    ManualClock? clock,
  }) async {
    late GameEngine engine;
    await tester.runAsync(() async {
      db = await folder.open();
      settings = AppSettings(db.settings);
      engine = GameEngine(
        config: config,
        database: db,
        clock: clock ?? ManualClock(),
      );
      await engine.startNewGame(name);
    });
    addTearDown(engine.dispose);
    return engine;
  }

  testWidgets('shows the company from the engine it was given', (tester) async {
    final engine = await engineWithGame(tester, 'Sifat Ltd');
    await tester.pumpWidget(app(engine));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Sifat Ltd'), findsOneWidget);
    expect(find.text('Cash: Tk 15,00,000'), findsOneWidget);
    expect(find.text('Turbo 20x'), findsOneWidget);
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      'Vehicle Manager Bangladesh',
    );
  });

  testWidgets('the turbo badge follows the clock through the UI clock', (
    tester,
  ) async {
    final clock = ManualClock();
    final engine = await engineWithGame(tester, 'A', clock: clock);
    await tester.pumpWidget(app(engine));
    expect(find.text('Turbo 20x'), findsOneWidget);

    // 20 minutes of foreground play moves the turbo to its second phase. The
    // screen notices on the next UI clock second, with no game change.
    clock.advance(const Duration(minutes: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Turbo 10x'), findsOneWidget);
  });

  testWidgets('without a game the new-game screen is shown', (tester) async {
    await tester.runAsync(() async {
      db = await folder.open();
      settings = AppSettings(db.settings);
    });
    final engine = GameEngine(
      config: config,
      database: db,
      clock: ManualClock(),
    );
    addTearDown(engine.dispose);
    await tester.pumpWidget(app(engine));
    expect(find.byType(NewGameScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Start your company'), findsOneWidget);
  });

  testWidgets('rebuilds when the engine notifies', (tester) async {
    final engine = await engineWithGame(tester, 'First');
    await tester.pumpWidget(app(engine));
    expect(find.text('First'), findsOneWidget);

    await tester.runAsync(() => engine.startNewGame('Second'));
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('puts the config, the engine and the settings in the tree', (
    tester,
  ) async {
    final engine = await engineWithGame(tester, 'A');
    await tester.pumpWidget(app(engine));

    final context = tester.element(find.byType(AppShell));
    expect(Provider.of<GameEngine>(context, listen: false), same(engine));
    expect(Provider.of<EconomyConfig>(context, listen: false), same(config));
    expect(Provider.of<AppSettings>(context, listen: false), same(settings));
  });

  group('language and theme', () {
    testWidgets('Bangla: Bangla text, digits and taka sign', (tester) async {
      final engine = await engineWithGame(tester, 'বাংলা লিমিটেড');
      await tester.runAsync(() => settings.setLanguage('bn'));
      await tester.pumpWidget(app(engine));

      expect(find.text('নগদ: ৳ ১৫,০০,০০০'), findsOneWidget);
      expect(find.text('টার্বো ২০ গুণ'), findsOneWidget);
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        'ভেহিকেল ম্যানেজার বাংলাদেশ',
      );
    });

    testWidgets('changing the language redraws at once', (tester) async {
      final engine = await engineWithGame(tester, 'A');
      await tester.pumpWidget(app(engine));
      expect(find.text('Cash: Tk 15,00,000'), findsOneWidget);

      await tester.runAsync(() => settings.setLanguage('bn'));
      await tester.pumpAndSettle();
      expect(find.text('নগদ: ৳ ১৫,০০,০০০'), findsOneWidget);
      expect(find.text('Cash: Tk 15,00,000'), findsNothing);

      await tester.runAsync(() => settings.setLanguage('en'));
      await tester.pumpAndSettle();
      expect(find.text('Cash: Tk 15,00,000'), findsOneWidget);
    });

    testWidgets('the theme mode setting reaches the MaterialApp', (
      tester,
    ) async {
      final engine = await engineWithGame(tester, 'A');
      await tester.pumpWidget(app(engine));
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );

      await tester.runAsync(() => settings.setThemeMode(ThemeMode.dark));
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });
  });

  group('the game loop', () {
    late CountingEngine engine;

    setUp(() async {
      db = await folder.open();
      settings = AppSettings(db.settings);
      engine = CountingEngine(config: config, database: db);
    });

    tearDown(() => engine.dispose());

    Widget loopApp() =>
        app(engine, loopInterval: const Duration(milliseconds: 20));

    testWidgets('ticks while the app lives and stops when it is removed', (
      tester,
    ) async {
      await tester.pumpWidget(loopApp());
      await tester.pump(const Duration(milliseconds: 105));
      expect(engine.ticks, greaterThanOrEqualTo(4));

      await tester.pumpWidget(const SizedBox());
      final ticks = engine.ticks;
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.ticks, ticks);
    });

    testWidgets('hiding the window pauses, coming back resumes', (
      tester,
    ) async {
      await tester.pumpWidget(loopApp());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(engine.pauses, 1);

      // Coming back from hidden passes through inactive, as the OS sends it.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(engine.resumes, 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a window that only lost focus does not pause', (tester) async {
      await tester.pumpWidget(loopApp());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.pauses, 0);
      expect(engine.ticks, greaterThanOrEqualTo(3));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
