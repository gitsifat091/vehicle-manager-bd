import 'package:flutter/services.dart' show rootBundle;

import 'core/config/economy_config.dart';
import 'core/sim/clock.dart';
import 'data/repositories/save_database.dart';
import 'platform/app_save_database.dart';
import 'platform/system_clock.dart';
import 'state/app_settings.dart';
import 'state/game_engine.dart';

/// What the app needs before its first frame.
class AppServices {
  const AppServices({
    required this.config,
    required this.engine,
    required this.settings,
  });

  final EconomyConfig config;
  final GameEngine engine;
  final AppSettings settings;
}

/// Loads the economy config, opens the save and starts the engine, which
/// finishes any interrupted save and catches up on the time away.
///
/// Tests pass their own [database] (a temp folder) and [clock]; the app uses
/// the device save and the system clock.
Future<AppServices> bootstrap({
  SaveDatabase? database,
  Clock clock = const SystemClock(),
}) async {
  final config = EconomyConfig.parse(
    await rootBundle.loadString('assets/config/economy.json'),
  );
  final db = database ?? await openAppSaveDatabase();
  final engine = GameEngine(config: config, database: db, clock: clock);
  await engine.start();
  return AppServices(
    config: config,
    engine: engine,
    settings: AppSettings(db.settings),
  );
}
