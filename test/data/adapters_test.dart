import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:vehicle_manager_bd/data/adapters/field_codec.dart';
import 'package:vehicle_manager_bd/data/adapters/game_adapters.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import 'fixtures.dart';
import 'save_test_helper.dart';

/// An older build of the vehicle adapter that knew only fields 0 to 2.
class _OldVehicleAdapter extends TypeAdapter<Vehicle> {
  @override
  final int typeId = HiveTypeIds.vehicle;

  @override
  Vehicle read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, Vehicle obj) {
    writeFields(writer, {
      0: obj.id,
      1: obj.tier,
      2: encodeInstant(obj.purchasedAt),
    });
  }
}

/// An older build of the company adapter, from before permits: fields 0 to 4.
class _OldCompanyAdapter extends TypeAdapter<Company> {
  @override
  final int typeId = HiveTypeIds.company;

  @override
  Company read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, Company obj) {
    writeFields(writer, {
      0: obj.name,
      1: obj.cash,
      2: encodeInstant(obj.createdAt),
      3: obj.completedTrips,
      4: obj.turboElapsed.inMilliseconds,
    });
  }
}

/// An older build of the route state adapter, from before game days were
/// stored: fields 0 to 2 only.
class _OldRouteStateAdapter extends TypeAdapter<RouteState> {
  @override
  final int typeId = HiveTypeIds.routeState;

  @override
  RouteState read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, RouteState obj) {
    writeFields(writer, {
      0: obj.routeId,
      1: obj.demandRemainingT,
      2: encodeInstant(obj.updatedAt),
    });
  }
}

/// An older build of the change set adapter, from before purchases, sales
/// and rollups: fields 0 to 4.
class _OldChangeSetAdapter extends TypeAdapter<ChangeSet> {
  @override
  final int typeId = HiveTypeIds.changeSet;

  @override
  ChangeSet read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, ChangeSet obj) {
    writeFields(writer, {
      0: obj.cashAfter,
      1: obj.completedTripsAfter,
      2: obj.vehicles,
      3: obj.trips,
      4: obj.routeStates,
    });
  }
}

/// A newer build that wrote a field this build has never heard of.
class _FutureVehicleAdapter extends VehicleAdapter {
  @override
  void write(BinaryWriter writer, Vehicle obj) {
    writeFields(writer, {
      0: obj.id,
      1: obj.tier,
      2: encodeInstant(obj.purchasedAt),
      3: obj.assignedRouteId,
      4: obj.assignedCargo,
      5: obj.overloadT,
      20: 'from the future',
    });
  }
}

void main() {
  final folder = SaveFolder()..register();

  test('every model survives a close and reopen unchanged', () async {
    final company = Company(
      name: 'Sifat Ltd',
      cash: 1234567,
      createdAt: t0,
      completedTrips: 7,
      turboElapsed: const Duration(minutes: 42, seconds: 7),
      permits: {'medium', 'light'},
      lifetimeRevenue: 987654,
      lifetimeCosts: sampleTrip().costs,
    );
    final vehicle = Vehicle(
      id: 'v1',
      tier: 6,
      purchasedAt: t0,
      assignedRouteId: 'R05',
      assignedCargo: 'Rice',
      overloadT: 4.5,
      availableAt: t0.add(const Duration(minutes: 5)),
    );
    final idle = Vehicle(id: 'v2', tier: 3, purchasedAt: t0, isStarter: true);
    final terminal = Terminal(id: 'term1', location: 'Dhaka', purchasedAt: t0);
    final route = RouteState(
      routeId: 'R05',
      demandRemainingT: 123.5,
      updatedAt: t0,
      gameDay: 29,
    );
    final trip = sampleTrip();
    final rollup = const DayRollup(gameDay: 41).add(trip);

    var db = await folder.open();
    await db.company.save(company);
    await db.vehicles.putAll([vehicle, idle]);
    await db.terminals.put(terminal);
    await db.routeStates.put(route);
    await db.trips.put(trip);
    await db.dayRollups.put(rollup);
    await db.close();

    db = await folder.open();
    expect(db.company.load(), company);
    expect(db.vehicles.get('v1'), vehicle);
    expect(db.vehicles.get('v2'), idle);
    expect(db.terminals.get('term1'), terminal);
    expect(db.routeStates.get('R05'), route);
    expect(db.trips.get('t1'), trip);
    expect(db.dayRollups.forDay(41), rollup);
  });

  group('change set fields survive the pending record', () {
    Future<ChangeSet> roundTrip(ChangeSet change) async {
      var db = await folder.open();
      await db.pending.save(change);
      await db.close();
      db = await folder.open();
      return db.pending.load()!;
    }

    test('a purchase, a sale, permits, totals and rollups', () async {
      final trip = sampleTrip(settled: true);
      final loaded = await roundTrip(
        ChangeSet(
          cashAfter: 5,
          completedTripsAfter: 6,
          vehicles: [Vehicle(id: 'v9', tier: 5, purchasedAt: t0)],
          removedVehicleIds: ['v1', 'v2'],
          removedTripIds: ['t7'],
          trips: [trip],
          permitsAfter: {'medium', 'light'},
          lifetimeRevenueAfter: 36375,
          lifetimeCostsAfter: trip.costs,
          dayRollups: [const DayRollup(gameDay: 4).add(trip)],
        ),
      );
      expect(loaded.cashAfter, 5);
      expect(loaded.completedTripsAfter, 6);
      expect(loaded.vehicles.single.id, 'v9');
      expect(loaded.removedVehicleIds, ['v1', 'v2']);
      expect(loaded.removedTripIds, ['t7']);
      expect(loaded.trips.single, trip);
      expect(loaded.permitsAfter, {'light', 'medium'});
      expect(loaded.lifetimeRevenueAfter, 36375);
      expect(loaded.lifetimeCostsAfter, trip.costs);
      expect(loaded.dayRollups, [const DayRollup(gameDay: 4).add(trip)]);
    });

    test(
      'unchanged stays unchanged, and an empty permit set stays empty',
      () async {
        final unchanged = await roundTrip(
          ChangeSet(cashAfter: 1, completedTripsAfter: 0),
        );
        expect(unchanged.permitsAfter, isNull);
        expect(unchanged.removedVehicleIds, isEmpty);
        expect(unchanged.removedTripIds, isEmpty);
        expect(unchanged.lifetimeRevenueAfter, isNull);
        expect(unchanged.lifetimeCostsAfter, isNull);
        expect(unchanged.dayRollups, isEmpty);

        final none = await roundTrip(
          ChangeSet(cashAfter: 1, completedTripsAfter: 0, permitsAfter: {}),
        );
        expect(none.permitsAfter, isEmpty);
      },
    );
  });

  test('timestamps come back as the same UTC instant', () async {
    var db = await folder.open();
    await db.trips.put(sampleTrip());
    await db.close();

    db = await folder.open();
    final trip = db.trips.get('t1')!;
    expect(trip.departAt.isUtc, true);
    expect(trip.arriveAt.isUtc, true);
    expect(trip.departAt, t0);
    expect(trip.arriveAt, t0.add(const Duration(minutes: 9)));
  });

  test(
    'a save from an older build loads with defaults for new fields',
    () async {
      Hive.init(folder.dir.path);
      Hive.registerAdapter(_OldVehicleAdapter(), override: true);
      final oldBox = await Hive.openBox<Vehicle>('vehicles');
      await oldBox.put(
        'v1',
        Vehicle(
          id: 'v1',
          tier: 4,
          purchasedAt: t0,
          assignedRouteId: 'R01',
          assignedCargo: 'Rice',
          overloadT: 2,
        ),
      );
      await Hive.close();
      Hive.registerAdapter(VehicleAdapter(), override: true);

      final db = await folder.open();
      final loaded = db.vehicles.get('v1')!;
      expect(loaded.id, 'v1');
      expect(loaded.tier, 4);
      expect(loaded.purchasedAt, t0);
      expect(loaded.assignedRouteId, isNull);
      expect(loaded.assignedCargo, isNull);
      expect(loaded.overloadT, 0);
      expect(loaded.availableAt, isNull);
      expect(loaded.isStarter, false);
    },
  );

  test('a company saved before permits existed owns none', () async {
    Hive.init(folder.dir.path);
    Hive.registerAdapter(_OldCompanyAdapter(), override: true);
    final oldBox = await Hive.openBox<Company>('company');
    await oldBox.put(
      'company',
      Company(name: 'Old Ltd', cash: 777, createdAt: t0, completedTrips: 4),
    );
    await Hive.close();
    Hive.registerAdapter(CompanyAdapter(), override: true);

    final db = await folder.open();
    final loaded = db.company.load()!;
    expect(loaded.name, 'Old Ltd');
    expect(loaded.cash, 777);
    expect(loaded.completedTrips, 4);
    expect(loaded.permits, isEmpty);
    expect(loaded.lifetimeRevenue, 0);
    expect(loaded.lifetimeCosts, TripCosts.zero);
  });

  test(
    'a pending change from before purchases and rollups still loads',
    () async {
      Hive.init(folder.dir.path);
      registerGameAdapters(Hive);
      Hive.registerAdapter(_OldChangeSetAdapter(), override: true);
      final oldBox = await Hive.openBox<ChangeSet>('pending_change');
      await oldBox.put(
        'pending',
        ChangeSet(
          cashAfter: 900,
          completedTripsAfter: 3,
          trips: [sampleTrip(settled: true)],
        ),
      );
      await Hive.close();
      Hive.registerAdapter(ChangeSetAdapter(), override: true);

      final db = await folder.open();
      final loaded = db.pending.load()!;
      expect(loaded.cashAfter, 900);
      expect(loaded.trips.single.settled, true);
      expect(loaded.permitsAfter, isNull, reason: 'permits stay as they are');
      expect(loaded.removedVehicleIds, isEmpty);
      expect(loaded.removedTripIds, isEmpty);
      expect(loaded.lifetimeRevenueAfter, isNull);
      expect(loaded.lifetimeCostsAfter, isNull);
      expect(loaded.dayRollups, isEmpty);
    },
  );

  test('permits survive a close and reopen, in any order', () async {
    var db = await folder.open();
    await db.company.save(
      Company(
        name: 'A',
        cash: 1,
        createdAt: t0,
        permits: {'hazmat', 'coldchain', 'heavy'},
      ),
    );
    await db.close();
    db = await folder.open();
    expect(db.company.load()!.permits, {'coldchain', 'hazmat', 'heavy'});
  });

  test('a route state saved before game days existed has no day', () async {
    Hive.init(folder.dir.path);
    Hive.registerAdapter(_OldRouteStateAdapter(), override: true);
    final oldBox = await Hive.openBox<RouteState>('route_states');
    await oldBox.put(
      'R05',
      RouteState(routeId: 'R05', demandRemainingT: 80, updatedAt: t0),
    );
    await Hive.close();
    Hive.registerAdapter(RouteStateAdapter(), override: true);

    final db = await folder.open();
    final loaded = db.routeStates.get('R05')!;
    expect(loaded.demandRemainingT, 80);
    expect(loaded.updatedAt, t0);
    expect(loaded.gameDay, isNull);
  });

  test('a field this build does not know is ignored', () async {
    Hive.init(folder.dir.path);
    Hive.registerAdapter(_FutureVehicleAdapter(), override: true);
    final box = await Hive.openBox<Vehicle>('vehicles');
    final vehicle = Vehicle(
      id: 'v1',
      tier: 6,
      purchasedAt: t0,
      assignedRouteId: 'R05',
      assignedCargo: 'Rice',
      overloadT: 3,
    );
    await box.put('v1', vehicle);
    await Hive.close();
    Hive.registerAdapter(VehicleAdapter(), override: true);

    final db = await folder.open();
    expect(db.vehicles.get('v1'), vehicle);
  });

  test('registering the adapters twice is harmless', () {
    registerGameAdapters(Hive);
    registerGameAdapters(Hive);
    expect(Hive.isAdapterRegistered(HiveTypeIds.trip), true);
  });

  test('type ids are unique', () {
    const ids = [
      HiveTypeIds.company,
      HiveTypeIds.vehicle,
      HiveTypeIds.terminal,
      HiveTypeIds.routeState,
      HiveTypeIds.trip,
      HiveTypeIds.tripCosts,
      HiveTypeIds.changeSet,
      HiveTypeIds.dayRollup,
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });
}
