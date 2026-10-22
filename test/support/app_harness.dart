import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:vehicle_manager_bd/app.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';
import 'package:vehicle_manager_bd/state/app_settings.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';

import 'sim_support.dart';

/// Builds the whole app on a temp-folder save and a clock moved by hand, for
/// widget tests of the screens.
///
/// Hive does real file IO, so everything that touches the save runs inside
/// `tester.runAsync`, and [settle] pumps until the engine is idle. The harness
/// owns its temp folder and removes it with `addTearDown`, which runs after
/// the test's fake-async zone is gone. (The shared `SaveFolder` closes Hive in
/// a plain `tearDown`, which inside a widget test cannot finish.)
///
/// Call [open] first, then [pump].
class AppHarness {
  /// [config] defaults to the default config with accidents off.
  AppHarness({EconomyConfig? config}) : config = config ?? quietConfig();

  final clock = ManualClock();

  /// Accidents are off by default, so trip money is exact.
  final EconomyConfig config;
  late Directory dir;
  late SaveDatabase db;
  late AppSettings settings;
  late GameEngine engine;

  /// Opens the save. With [company] a game is started; with [language] the
  /// device setting is chosen before the first frame.
  Future<void> open(
    WidgetTester tester, {
    String? company,
    String? language,
  }) async {
    dir = Directory.systemTemp.createTempSync('vm_ui_test_');
    addTearDown(() async {
      await Hive.close().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <void>[],
      );
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold the file for a moment. A leftover temp
        // folder does no harm.
      }
    });
    await tester.runAsync(() async {
      db = await SaveDatabase.openAt(dir.path);
      settings = AppSettings(db.settings);
      if (language != null) await settings.setLanguage(language);
      engine = GameEngine(
        config: config,
        database: db,
        clock: clock,
        newId: counterIds(),
      );
      if (company != null) await engine.startNewGame(company);
    });
    addTearDown(engine.dispose);
  }

  Widget get app =>
      VehicleManagerApp(config: config, engine: engine, settings: settings);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(app);

  /// Runs one engine tick the way the game loop does, inside the test's own
  /// zone, and waits for it.
  ///
  /// Once a test has started a save operation in the test zone (a tap on a
  /// button), later ones must run there too. Starting one in `runAsync` after
  /// that deadlocks inside Hive.
  Future<void> tick(WidgetTester tester) {
    unawaited(engine.tick());
    return settle(tester);
  }

  /// Lets the engine finish what it is doing and then redraws.
  ///
  /// A save write is several file operations in a row. Each one finishes in
  /// real time, but what follows it runs on the test's fake clock, so the
  /// real wait and the pump are repeated until the engine is idle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 400; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      // A duration, not a bare pump: Hive uses timers, which only fire when
      // the fake clock moves.
      await tester.pump(const Duration(milliseconds: 20));
      if (!engine.isBusy) return;
    }
    fail('The engine was still busy after 4 seconds.');
  }
}
