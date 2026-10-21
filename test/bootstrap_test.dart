import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/bootstrap.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';

import 'core/test_config.dart';
import 'data/save_test_helper.dart';
import 'support/sim_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final folder = SaveFolder()..register();

  test('loads the bundled economy config', () async {
    final services = await bootstrap(
      database: await folder.open(),
      clock: ManualClock(),
    );
    addTearDown(services.engine.dispose);
    expect(services.config.version, loadDefaultConfig().version);
    expect(services.config.vehicles, hasLength(12));
    expect(services.engine.company, isNull, reason: 'no game on a new save');
  });

  test('starts the engine on an existing save', () async {
    final clock = ManualClock();
    var db = await folder.open();
    final first = GameEngine(
      config: loadDefaultConfig(),
      database: db,
      clock: clock,
    );
    await first.startNewGame('Saved Ltd');
    first.dispose();
    await db.close();

    clock.advance(const Duration(minutes: 30));
    db = await folder.open();
    final services = await bootstrap(database: db, clock: clock);
    addTearDown(services.engine.dispose);
    expect(services.engine.company!.name, 'Saved Ltd');
    // start() resumed the turbo clock from the saved foreground time.
    expect(services.engine.turboElapsed, Duration.zero);
    clock.advance(const Duration(minutes: 1));
    expect(services.engine.turboElapsed, const Duration(minutes: 1));
  });
}
