import '../config/economy_config.dart';
import 'clock.dart';

/// One step of the Turbo Start: [speed] applies until [end] of foreground play.
class TurboPhase {
  const TurboPhase({required this.end, required this.speed});

  final Duration end;
  final double speed;
}

/// The Turbo Start phases from the config: for example 20x for the first 20
/// minutes, 10x until 40, 5x until 60, then 1x.
class TurboSchedule {
  const TurboSchedule(this.phases);

  factory TurboSchedule.fromSettings(EconomySettings s) {
    return TurboSchedule([
      TurboPhase(
        end: Duration(minutes: s.turboPhase1EndMin),
        speed: s.turboPhase1Speed,
      ),
      TurboPhase(
        end: Duration(minutes: s.turboPhase2EndMin),
        speed: s.turboPhase2Speed,
      ),
      TurboPhase(
        end: Duration(minutes: s.turboPhase3EndMin),
        speed: s.turboPhase3Speed,
      ),
    ]);
  }

  /// In order, with growing [TurboPhase.end].
  final List<TurboPhase> phases;

  /// Foreground time after which the turbo is over.
  Duration get total => phases.isEmpty ? Duration.zero : phases.last.end;

  /// The speed multiplier after [elapsed] of foreground play. A phase ends
  /// exactly at its end time, so 20:00 already runs at the second speed.
  double speedAt(Duration elapsed) {
    for (final phase in phases) {
      if (elapsed < phase.end) return phase.speed;
    }
    return 1;
  }

  bool isActiveAt(Duration elapsed) => elapsed < total;
}

/// Counts foreground play time for the Turbo Start.
///
/// Time only counts between [resume] and [pause]. While the app is in the
/// background nothing is added, so leaving the game does not burn the turbo.
class TurboClock {
  TurboClock({
    required this.schedule,
    required Clock clock,
    Duration accumulated = Duration.zero,
  }) : _clock = clock,
       _accumulated = accumulated;

  final TurboSchedule schedule;
  final Clock _clock;
  Duration _accumulated;
  DateTime? _foregroundSince;

  bool get isForeground => _foregroundSince != null;

  /// Foreground time so far, including the current stretch.
  Duration get elapsed {
    final since = _foregroundSince;
    if (since == null) return _accumulated;
    final running = _clock.now().difference(since);
    return running.isNegative ? _accumulated : _accumulated + running;
  }

  /// The speed multiplier to use for a dispatch right now.
  double get speed => schedule.speedAt(elapsed);

  /// The app came to the foreground. Does nothing if it already is.
  void resume() {
    _foregroundSince ??= _clock.now();
  }

  /// The app went to the background. Freezes [elapsed] and returns it, which
  /// is the value to save. Does nothing if it already is.
  Duration pause() {
    _accumulated = elapsed;
    _foregroundSince = null;
    return _accumulated;
  }
}
