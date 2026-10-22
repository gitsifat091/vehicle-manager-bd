import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/config/economy_config.dart';
import '../core/economy/purchase_rules.dart';
import '../core/economy/unlock_rules.dart';
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
/// never interleave their reads and writes, and each starts by finishing any
/// save left half written.
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
    final trips = _db.trips.all();
    return GameSnapshot(
      company: _db.company.load(),
      vehicles: vehicles,
      activeTrips: trips.where((t) => !t.settled),
      settledTrips: trips.where((t) => t.settled),
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
    // _serial has already finished any save a crash interrupted.
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
        isStarter: true,
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

  /// Buys a new vehicle of [tier] for its price. It arrives in the garage
  /// unassigned. Refused, with nothing saved, when the vehicle is locked, the
  /// garage is full or the cash is short (`checkVehiclePurchase`).
  ///
  /// Throws a [StateError] when there is no game.
  Future<VehiclePurchaseOutcome> buyVehicle(int tier) => _serial(() async {
    final company = _requireCompany();
    final spec = config.vehicleByTier(tier);
    final rejection = checkVehiclePurchase(
      settings: config.settings,
      vehicle: spec,
      cash: company.cash,
      vehiclesOwned: _db.vehicles.count,
      completedTrips: company.completedTrips,
      ownedPermits: company.permits,
    );
    if (rejection != null) return VehiclePurchaseOutcome.refused(rejection);

    final vehicle = Vehicle(
      id: _newId('veh'),
      tier: tier,
      purchasedAt: _clock.now(),
    );
    await _committer.commit(
      ChangeSet(
        cashAfter: company.cash - spec.priceTk,
        completedTripsAfter: company.completedTrips,
        vehicles: [vehicle],
      ),
    );
    notifyListeners();
    return VehiclePurchaseOutcome.bought(vehicle);
  });

  /// Buys the operating permit [permitId] once, for its price in Taka. Returns
  /// why it was refused (already owned, cash short), or null when bought.
  ///
  /// Throws a [StateError] when there is no game.
  Future<PermitRejection?> buyPermit(String permitId) => _serial(() async {
    final company = _requireCompany();
    final permit = config.permitById(permitId);
    final rejection = checkPermitPurchase(
      permit: permit,
      cash: company.cash,
      ownedPermits: company.permits,
    );
    if (rejection != null) return rejection;

    await _committer.commit(
      ChangeSet(
        cashAfter: company.cash - permit.priceTk,
        completedTripsAfter: company.completedTrips,
        permitsAfter: {...company.permits, permit.id},
      ),
    );
    notifyListeners();
    return null;
  });

  /// Takes the route and cargo away from [vehicleId]. A trip already on the
  /// road still finishes and is paid; the vehicle then stays in the garage
  /// instead of going out again. This is the first step of selling. Returns
  /// false when the vehicle is not in the garage.
  ///
  /// Throws a [StateError] when there is no game.
  Future<bool> unassignVehicle(String vehicleId) => _serial(() async {
    final company = _requireCompany();
    final vehicle = _db.vehicles.get(vehicleId);
    if (vehicle == null) return false;
    if (!vehicle.isAssigned) return true;
    await _committer.commit(
      ChangeSet(
        cashAfter: company.cash,
        completedTripsAfter: company.completedTrips,
        vehicles: [vehicle.withoutAssignment()],
      ),
    );
    notifyListeners();
    return true;
  });

  /// Sells [vehicleId] and frees its garage slot. It pays `saleValueTk`: the
  /// fixed starter sale value for the free starter, the resale share of the
  /// price for any other vehicle. Refused (`checkSale`) while the vehicle is
  /// on the road (unassign it, let the trip finish, then sell), and for the
  /// last vehicle when the cash after the sale would not buy the cheapest
  /// vehicle the company can buy. Returns why it was refused, or null when
  /// sold.
  ///
  /// Throws a [StateError] when there is no game.
  Future<SaleRejection?> sellVehicle(String vehicleId) => _serial(() async {
    final company = _requireCompany();
    final vehicle = _db.vehicles.get(vehicleId);
    if (vehicle == null) {
      return SaleRejection(
        SaleRejectionReason.notOwned,
        'Vehicle $vehicleId is not in the garage.',
      );
    }
    final cashAfter =
        company.cash +
        saleValueTk(
          settings: config.settings,
          vehicle: config.vehicleByTier(vehicle.tier),
          isStarter: vehicle.isStarter,
        );
    final rejection = checkSale(
      onTheRoad: _db.trips.activeFor(vehicleId) != null,
      vehiclesOwned: _db.vehicles.count,
      cashAfterSale: cashAfter,
      cheapestBuyableTk: cheapestBuyablePriceTk(
        config: config,
        completedTrips: company.completedTrips,
        ownedPermits: company.permits,
      ),
    );
    if (rejection != null) return rejection;

    await _committer.commit(
      ChangeSet(
        cashAfter: cashAfter,
        completedTripsAfter: company.completedTrips,
        removedVehicleIds: [vehicleId],
      ),
    );
    notifyListeners();
    return null;
  });

  Company _requireCompany() {
    final company = _db.company.load();
    if (company == null) throw StateError('There is no game to buy for.');
    return company;
  }

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
    final settled = _simulator.advance(
      world: _loadWorld(),
      now: _clock.now(),
      turboSpeed: turbo.speed,
      turboBonus: _schedule.bonusAt(turbo.elapsed),
    );
    // Pruning rides along with a settlement, which is when the history grows.
    final change = settled.isEmpty
        ? settled
        : settled.withRemovedTrips(_tripsToPrune());
    if (!change.isEmpty) {
      await _committer.commit(change);
    }
    await _saveTurbo();
    if (!change.isEmpty) notifyListeners();
  }

  /// Settled trips kept on disk for the trip history. Older ones are deleted;
  /// the lifetime totals and day rollups already count them.
  static const keptSettledTrips = 500;

  /// How far past [keptSettledTrips] the history may grow before it is cut
  /// back, so pruning runs now and then rather than on every settlement.
  static const pruneSlack = 50;

  /// Ids of the oldest settled trips on disk beyond [keptSettledTrips], once
  /// there are more than [keptSettledTrips] + [pruneSlack]. Every settled trip
  /// on disk was counted in the commit that settled it, so deleting it loses
  /// nothing. Trips still on the road are never pruned.
  List<String> _tripsToPrune() {
    final settledCount = _db.trips.count - _db.trips.unsettled().length;
    if (settledCount <= keptSettledTrips + pruneSlack) return const [];
    final settled = _db.trips.all().where((t) => t.settled).toList()
      ..sort((a, b) {
        final byArrival = b.arriveAt.compareTo(a.arriveAt);
        return byArrival != 0 ? byArrival : b.id.compareTo(a.id);
      });
    return [for (final t in settled.skip(keptSettledTrips)) t.id];
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
      rollupOf: _db.dayRollups.forDay,
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

  /// Queues [operation] behind the ones already running. Before it reads
  /// anything, a save that an earlier operation left half written (a commit
  /// that threw while the app kept running) is finished first. Otherwise the
  /// operation would compute from a half-applied save, and committing its
  /// result after the leftover could pay a trip twice or hand out a vehicle
  /// for free.
  Future<T> _serial<T>(Future<T> Function() operation) {
    _pending++;
    final result = _tail.then((_) async {
      await _committer.recoverPending();
      return operation();
    });
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

/// The result of [GameEngine.buyVehicle]: the new vehicle, or why the
/// purchase was refused.
class VehiclePurchaseOutcome {
  const VehiclePurchaseOutcome.bought(Vehicle this.vehicle) : rejection = null;

  const VehiclePurchaseOutcome.refused(PurchaseRejection this.rejection)
    : vehicle = null;

  /// The vehicle now in the garage, unassigned. Null when refused.
  final Vehicle? vehicle;

  /// Why nothing was bought. Null when bought.
  final PurchaseRejection? rejection;

  bool get bought => vehicle != null;
}
