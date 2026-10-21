import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/sim/vehicle_status.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';

import '../data/save_test_helper.dart';
import '../support/sim_support.dart';

void main() {
  final folder = SaveFolder()..register();
  late ManualClock clock;
  late SaveDatabase db;
  late GameEngine engine;

  setUp(() async {
    clock = ManualClock();
    db = await folder.open();
    engine = GameEngine(
      config: quietConfig(),
      database: db,
      clock: clock,
      newId: counterIds(),
    );
  });

  tearDown(() => engine.dispose());

  Future<void> finishTurbo() async {
    clock.advance(const Duration(minutes: 61));
    await engine.tick();
  }

  test('without a game the snapshot is empty', () {
    final s = engine.snapshot;
    expect(s.hasGame, false);
    expect(s.company, isNull);
    expect(s.vehicles, isEmpty);
    expect(s.permits, isEmpty);
    expect(s.vehicleById('v1'), isNull);
  });

  test(
    'a new game: company, full demand on every route, 6 free slots',
    () async {
      await engine.startNewGame('Sifat Ltd');
      final s = engine.snapshot;
      expect(s.hasGame, true);
      expect(s.company!.name, 'Sifat Ltd');
      expect(s.company!.cash, 1500000);
      expect(s.routeStateById, hasLength(16));
      expect(s.routeStateById['R01']!.demandRemainingT, 60);
      expect(s.garageSlots, 6);
      expect(s.freeGarageSlots, 6);
    },
  );

  test('the same instance comes back until the engine notifies', () async {
    await engine.startNewGame('A');
    final first = engine.snapshot;
    expect(engine.snapshot, same(first));

    await engine.startNewGame('B');
    final second = engine.snapshot;
    expect(second, isNot(same(first)));
    expect(second.company!.name, 'B');
    expect(first.company!.name, 'A', reason: 'an old snapshot never changes');
  });

  test(
    'vehicles come oldest first, with the free slots counted down',
    () async {
      await engine.startNewGame('A');
      await db.vehicles.putAll([
        Vehicle(
          id: 'late',
          tier: 4,
          purchasedAt: t0.add(const Duration(hours: 2)),
        ),
        Vehicle(id: 'early', tier: 4, purchasedAt: t0),
        Vehicle(id: 'also_early', tier: 3, purchasedAt: t0),
      ]);
      await engine.tick();
      // An empty tick does not notify, so ask for a fresh read by notifying.
      engine.notifyListeners();
      final s = engine.snapshot;
      expect(s.vehicles.map((v) => v.id), ['also_early', 'early', 'late']);
      expect(s.freeGarageSlots, 3);
    },
  );

  test('a vehicle on the road shows its trip and progress', () async {
    await engine.startNewGame('A');
    await finishTurbo();
    await db.vehicles.put(Vehicle(id: 'v1', tier: 4, purchasedAt: clock.now()));
    await engine.assignVehicle('v1', routeId: 'R01', cargoName: 'General dry');

    final s = engine.snapshot;
    final vehicle = s.vehicleById('v1')!;
    expect(vehicle.assignedRouteId, 'R01');
    final trip = s.activeTripByVehicle['v1']!;
    expect(trip.routeId, 'R01');

    final half = clock.now().add(const Duration(seconds: 42));
    final activity = s.activityOf(vehicle, half);
    expect(activity.status, VehicleStatus.onTheRoad);
    expect(activity.progress, closeTo(0.5, 1e-9));
  });

  test('after the trip is paid, it leaves the active trips', () async {
    await engine.startNewGame('A');
    await finishTurbo();
    await db.vehicles.put(Vehicle(id: 'v1', tier: 4, purchasedAt: clock.now()));
    await engine.assignVehicle('v1', routeId: 'R01', cargoName: 'General dry');
    final before = engine.snapshot.company!.cash;

    clock.advance(const Duration(seconds: 100));
    await engine.tick();
    final s = engine.snapshot;
    expect(s.company!.cash, before + 2183);
    expect(s.company!.completedTrips, 1);
    // The Local haul went out again at the moment the first trip arrived.
    expect(s.activeTripByVehicle, hasLength(1));
    expect(s.activeTripByVehicle['v1']!.settled, false);
  });

  test('an unassigned vehicle is idle and a waiting one is waiting', () async {
    await engine.startNewGame('A');
    await finishTurbo();
    await db.vehicles.put(
      Vehicle(id: 'idle', tier: 4, purchasedAt: clock.now()),
    );
    await db.vehicles.put(Vehicle(id: 'w', tier: 4, purchasedAt: clock.now()));
    // No day number: the day is worked out from the timestamp, so today's
    // demand is empty and the vehicle has to wait for tomorrow.
    await db.routeStates.put(
      RouteState(routeId: 'R01', demandRemainingT: 0, updatedAt: clock.now()),
    );
    await engine.assignVehicle('w', routeId: 'R01', cargoName: 'General dry');

    final s = engine.snapshot;
    expect(
      s.activityOf(s.vehicleById('idle')!, clock.now()).status,
      VehicleStatus.idle,
    );
    final waiting = s.activityOf(s.vehicleById('w')!, clock.now());
    expect(waiting.status, VehicleStatus.waitingForDemand);
    expect(waiting.until!.isAfter(clock.now()), true);
  });

  test('permits come from the company', () async {
    await engine.startNewGame('A');
    final company = db.company.load()!;
    await db.company.save(company.copyWith(permits: {'light'}));
    engine.notifyListeners();
    expect(engine.snapshot.permits, {'light'});
  });

  test('a restart reads the saved game', () async {
    await engine.startNewGame('Saved');
    await db.vehicles.put(Vehicle(id: 'v1', tier: 4, purchasedAt: t0));
    await db.close();

    db = await folder.open();
    final restarted = GameEngine(
      config: quietConfig(),
      database: db,
      clock: clock,
    );
    addTearDown(restarted.dispose);
    await restarted.start();
    expect(restarted.snapshot.company!.name, 'Saved');
    expect(restarted.snapshot.vehicles.map((v) => v.id), ['v1']);
  });
}
