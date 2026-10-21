import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/config/economy_config.dart';
import '../core/sim/clock.dart';
import '../core/sim/dispatch.dart';
import '../core/sim/game_simulator.dart';
import '../core/sim/turbo.dart';
import '../data/id_generator.dart';
import '../data/models/models.dart';
import '../data/repositories/change_committer.dart';
import '../data/repositories/save_database.dart';
import 'game_snapshot.dart';

/// Runs the game on top of the save: loads the state, lets the simulator move
/// it forward, and saves the result through the [ChangeCommitter].
///
/// Every operation runs one after another, so a timer tick and a player action
/// never interleave their reads and writes.
class GameEngine extends ChangeNotifier {
  GameEngine({
    required this.config,
    required SaveDatabase database,
    required Clock clock,
    Random? random,
    String Function(String prefix)? newId,
    ChangeCommitter? committer,
    int maxStepsPerVehicle = GameSimulator.defaultMaxStepsPerVehicle,
  }) : _db = database,
       _clock = clock,
       _newId = newId ?? ((prefix) => newIdAt(prefix, clock.now())),
       _committer = committer ?? ChangeCommitter(database),
       _simulator = GameSimulator(
         config: config,
         random: random ?? Random(),
         newId: newId ?? ((prefix) => newIdAt(prefix, clock.now())),
         maxStepsPerVehicle: maxStepsPerVehicle,
       ),
       _schedule = TurboSchedule.fromSettings(config.settings);

  final EconomyConfig config;
  final SaveDatabase _db;
  final Clock _clock;
  final String Function(String prefix) _newId;
  final ChangeCommitter _committer;
  final GameSimulator _simulator;
  final TurboSchedule _schedule;

  TurboClock? _turbo;
  Future<void> _tail = Future.value();
  GameSnapshot? _snapshot;

  /// The clock this engine runs on. The UI clock uses the same one.
  Clock get clock => _clock;

  /// The saved company, or null before a game exists.
  Company? get company => _db.company.load();

  /// A read-only copy of the game for the screens. The same instance is
  /// returned until the engine next notifies its listeners, so
  /// `context.select((GameEngine e) => e.snapshot)` rebuilds only on a real
  /// change.
  GameSnapshot get snapshot => _snapshot ??= _buildSnapshot();

  GameSnapshot _buildSnapshot() {
    final vehicles = _db.vehicles.all()
      ..sort((a, b) {
        final byTime = a.purchasedAt.compareTo(b.purchasedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return GameSnapshot(
      company: _db.company.load(),
      vehicles: vehicles,
      activeTrips: _db.trips.unsettled(),
      routeStates: _db.routeStates.all(),
      settings: config.settings,
    );
  }

  @override
  void notifyListeners() {
    _snapshot = null;
    super.notifyListeners();
  }

  /// The Turbo Start multiplier a dispatch would get right now.
  double get turboSpeed => _turbo?.speed ?? 1;

  /// Foreground play time used by the Turbo Start so far.
  Duration get turboElapsed => _turbo?.elapsed ?? Duration.zero;

  /// Game clock time earned by the Turbo Start so far. The game clock is real
  /// time plus this, so game days run faster while the turbo lasts.
  Duration get turboBonus => _schedule.bonusAt(turboElapsed);

  /// Opens the saved game: finishes any interrupted save, starts counting
  /// foreground time, and catches up on everything that happened while away.
  /// Does nothing if there is no saved company yet.
  Future<void> start() => _serial(() async {
    await _committer.recoverPending();
    final saved = _db.company.load();
    if (saved == null) return;
    _turbo = TurboClock(
      schedule: _schedule,
      clock: _clock,
      accumulated: saved.turboElapsed,
    )..resume();
    await _advance();
    notifyListeners();
  });

  /// Erases the save and starts a new company with the starting cash and the
  /// free starter vehicle (`settings.starterVehicleTier`), not yet assigned.
  ///
  /// The company is written last. Every other record is useless without it,
  /// so if the app dies half way the save has no company and the player just
  /// sees the new-game screen again, never a half-made company.
  Future<void> startNewGame(String name) => _serial(() async {
    await _db.clearAll();
    final now = _clock.now();
    await _db.routeStates.putAll([
      for (final route in config.routes)
        RouteState.initial(route, now, gameDay: 0),
    ]);
    await _db.vehicles.put(
      Vehicle(
        id: _newId('veh'),
        tier: config.settings.starterVehicleTier,
        purchasedAt: now,
      ),
    );
    await _db.company.save(
      Company.newGame(config: config, name: name, now: now),
    );
    _turbo = TurboClock(schedule: _schedule, clock: _clock)..resume();
    notifyListeners();
  });

  /// Settles arrived trips and redispatches Local hauls. Called by the timer.
  Future<void> tick() => _serial(_advance);

  /// The app came to the foreground: the Turbo Start counts again.
  Future<void> resume() => _serial(() async {
    _turbo?.resume();
  });

  /// The app went to the background: freezes the Turbo Start and saves it.
  Future<void> pause() => _serial(() async {
    _turbo?.pause();
    await _saveTurbo();
  });

  /// Gives an idle vehicle a route, cargo and overload, and sends it out now.
  /// The assignment is kept only if the vehicle can depart or wait for demand.
  Future<DispatchOutcome> assignVehicle(
    String vehicleId, {
    required String routeId,
    required String cargoName,
    double overloadT = 0,
  }) => _serial(() async {
    final vehicle = _db.vehicles.get(vehicleId);
    if (vehicle == null || _db.company.load() == null) {
      return const DispatchOutcome(
        DispatchBlocked(DispatchBlockReason.unknownVehicle),
      );
    }
    final assigned = vehicle.withAssignment(
      routeId: routeId,
      cargoName: cargoName,
      overloadT: overloadT,
      availableAt: _clock.now(),
    );
    return _dispatch(assigned);
  });

  /// Sends an assigned, idle vehicle out again now (for Line hauls, which do
  /// not repeat by themselves).
  Future<DispatchOutcome> dispatchVehicle(String vehicleId) =>
      _serial(() async {
        final vehicle = _db.vehicles.get(vehicleId);
        if (vehicle == null || _db.company.load() == null) {
          return const DispatchOutcome(
            DispatchBlocked(DispatchBlockReason.unknownVehicle),
          );
        }
        return _dispatch(vehicle);
      });

  Future<DispatchOutcome> _dispatch(Vehicle vehicle) async {
    final outcome = _simulator.dispatchNow(
      world: _loadWorld(replacing: vehicle),
      vehicleId: vehicle.id,
      now: _clock.now(),
      turboSpeed: turboSpeed,
      turboBonus: turboBonus,
    );
    final change = outcome.change;
    if (change != null) {
      await _committer.commit(change);
      notifyListeners();
    }
    return outcome;
  }

  Future<void> _advance() async {
    final turbo = _turbo;
    if (turbo == null || _db.company.load() == null) return;
    final change = _simulator.advance(
      world: _loadWorld(),
      now: _clock.now(),
      turboSpeed: turbo.speed,
      turboBonus: _schedule.bonusAt(turbo.elapsed),
    );
    if (!change.isEmpty) {
      await _committer.commit(change);
    }
    await _saveTurbo();
    if (!change.isEmpty) notifyListeners();
  }

  SimWorld _loadWorld({Vehicle? replacing}) {
    final vehicles = _db.vehicles.all();
    if (replacing != null) {
      final index = vehicles.indexWhere((v) => v.id == replacing.id);
      if (index >= 0) vehicles[index] = replacing;
    }
    return SimWorld(
      company: _db.company.load()!,
      vehicles: vehicles,
      unsettledTrips: _db.trips.unsettled(),
      routeStates: _db.routeStates.all(),
    );
  }

  /// Saves the foreground time while the Turbo Start is running. After it is
  /// over the stored value is capped, so there is nothing more to write.
  Future<void> _saveTurbo() async {
    final turbo = _turbo;
    final saved = _db.company.load();
    if (turbo == null || saved == null) return;
    final elapsed = turbo.elapsed > _schedule.total
        ? _schedule.total
        : turbo.elapsed;
    if (elapsed != saved.turboElapsed) {
      await _db.company.save(saved.copyWith(turboElapsed: elapsed));
    }
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    _pending++;
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) => _pending--,
      onError: (_) {
        _pending--;
      },
    );
    return result;
  }

  int _pending = 0;

  /// True while an operation (a tick, a purchase, a new game) is queued or
  /// running. Widget tests pump until this is false, because a save write is a
  /// chain of file operations that finish in real time.
  @visibleForTesting
  bool get isBusy => _pending > 0;
}
