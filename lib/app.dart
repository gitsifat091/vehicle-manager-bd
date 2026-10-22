import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/economy_config.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_context.dart';
import 'state/app_settings.dart';
import 'state/game_engine.dart';
import 'state/game_loop.dart';
import 'state/ui_clock.dart';
import 'ui/screens/new_game_screen.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme/app_theme.dart';

/// The app root. It owns the [GameLoop] (ticks while the widget lives) and
/// puts the config, the engine and the device settings in the widget tree for
/// the screens.
///
/// The engine and settings are created by the caller (see `bootstrap`), so
/// tests can give them a temp-folder save and a clock they move by hand.
class VehicleManagerApp extends StatefulWidget {
  const VehicleManagerApp({
    super.key,
    required this.config,
    required this.engine,
    required this.settings,
    this.loopInterval = const Duration(seconds: 3),
  });

  final EconomyConfig config;
  final GameEngine engine;
  final AppSettings settings;
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
        ChangeNotifierProvider<AppSettings>.value(value: widget.settings),
      ],
      child: Consumer<AppSettings>(
        builder: (context, settings, _) => MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          // Null follows the device; the first supported locale (English) is
          // the fallback when the device speaks something else.
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppHome(),
        ),
      ),
    );
  }
}

/// Chooses the first screen: the new-game screen until a company exists, then
/// the shell with its pages.
class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    final hasGame = context.select((GameEngine e) => e.snapshot.hasGame);
    return hasGame ? const AppShell() : const NewGameScreen();
  }
}
