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
    );
    final vehicle = Vehicle(
      id: 'v1',
      tier: 6,
      purchasedAt: t0,
      assignedRouteId: 'R05',
      assignedCargo: 'Rice',
      overloadT: 4.5,
    );
    final idle = Vehicle(id: 'v2', tier: 3, purchasedAt: t0);
    final terminal = Terminal(id: 'term1', location: 'Dhaka', purchasedAt: t0);
    final route = RouteState(
      routeId: 'R05',
      demandRemainingT: 123.5,
      updatedAt: t0,
    );
    final trip = sampleTrip();

    var db = await folder.open();
    await db.company.save(company);
    await db.vehicles.putAll([vehicle, idle]);
    await db.terminals.put(terminal);
    await db.routeStates.put(route);
    await db.trips.put(trip);
    await db.close();

    db = await folder.open();
    expect(db.company.load(), company);
    expect(db.vehicles.get('v1'), vehicle);
    expect(db.vehicles.get('v2'), idle);
    expect(db.terminals.get('term1'), terminal);
    expect(db.routeStates.get('R05'), route);
    expect(db.trips.get('t1'), trip);
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
    },
  );

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
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });
}
