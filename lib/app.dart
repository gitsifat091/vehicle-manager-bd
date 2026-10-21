import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/economy_config.dart';
import 'state/game_engine.dart';
import 'state/game_loop.dart';
import 'state/ui_clock.dart';
import 'ui/theme/app_theme.dart';

/// The app root. It owns the [GameLoop] (ticks while the widget lives) and
/// puts the config and the engine in the widget tree for the screens.
///
/// The engine is created by the caller (see `bootstrap`), so tests can give
/// it a temp-folder save and a clock they move by hand.
class VehicleManagerApp extends StatefulWidget {
  const VehicleManagerApp({
    super.key,
    required this.config,
    required this.engine,
    this.loopInterval = const Duration(seconds: 3),
  });

  final EconomyConfig config;
  final GameEngine engine;
  final Duration loopInterval;

  @override
  State<VehicleManagerApp> createState() => _VehicleManagerAppState();
}

class _VehicleManagerAppState extends State<VehicleManagerApp> {
  late final GameLoop _loop;
  late final UiClock _uiClock;

  @override
  void initState() {
    super.initState();
    _loop = GameLoop(widget.engine, interval: widget.loopInterval)..start();
    _uiClock = UiClock(widget.engine.clock)..start();
  }

  @override
  void dispose() {
    _loop.stop();
    _uiClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<EconomyConfig>.value(value: widget.config),
        ChangeNotifierProvider<GameEngine>.value(value: widget.engine),
        ChangeNotifierProvider<UiClock>.value(value: _uiClock),
      ],
      child: MaterialApp(
        title: 'Vehicle Manager Bangladesh',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const PlaceholderScreen(),
      ),
    );
  }
}

// Temporary home screen until the real screens exist (Milestone 4). Its
// English strings are replaced by ARB strings in step 4.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The snapshot changes when the game does; the UI clock makes the turbo
    // speed (which moves with time) look at the clock again.
    final snapshot = context.select((GameEngine e) => e.snapshot);
    context.watch<UiClock>();
    final engine = context.read<GameEngine>();
    final company = snapshot.company;
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Manager Bangladesh')),
      body: Center(
        child: company == null
            ? const Text('No game yet')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(company.name),
                  Text('Tk ${company.cash}'),
                  Text('Turbo ${engine.turboSpeed.toStringAsFixed(0)}x'),
                ],
              ),
      ),
    );
  }
}
