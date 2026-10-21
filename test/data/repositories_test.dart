import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/data/id_generator.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';

import 'fixtures.dart';
import 'save_test_helper.dart';

void main() {
  final folder = SaveFolder()..register();
  late SaveDatabase db;

  setUp(() async {
    db = await folder.open();
  });

  group('CompanyRepository', () {
    test('is empty before a new game', () {
      expect(db.company.exists, false);
      expect(db.company.load(), isNull);
    });

    test('saves and loads', () async {
      final c = Company(name: 'A', cash: 100, createdAt: t0);
      await db.company.save(c);
      expect(db.company.exists, true);
      expect(db.company.load(), c);
    });

    test('save replaces the previous company', () async {
      final c = Company(name: 'A', cash: 100, createdAt: t0);
      await db.company.save(c);
      await db.company.save(c.copyWith(cash: 250));
      expect(db.company.load()!.cash, 250);
      expect(db.company.box.length, 1);
    });
  });

  group('VehicleRepository', () {
    test('put, get, update, delete', () async {
      final v = Vehicle(id: 'v1', tier: 4, purchasedAt: t0);
      await db.vehicles.put(v);
      expect(db.vehicles.get('v1'), v);
      expect(db.vehicles.count, 1);

      final assigned = v.withAssignment(routeId: 'R01', cargoName: 'Rice');
      await db.vehicles.put(assigned);
      expect(db.vehicles.count, 1);
      expect(db.vehicles.get('v1')!.assignedRouteId, 'R01');

      await db.vehicles.delete('v1');
      expect(db.vehicles.get('v1'), isNull);
      expect(db.vehicles.count, 0);
    });

    test('byTier filters', () async {
      await db.vehicles.putAll([
        Vehicle(id: 'a', tier: 4, purchasedAt: t0),
        Vehicle(id: 'b', tier: 6, purchasedAt: t0),
        Vehicle(id: 'c', tier: 4, purchasedAt: t0),
      ]);
      expect(db.vehicles.byTier(4).map((v) => v.id).toSet(), {'a', 'c'});
      expect(db.vehicles.byTier(9), isEmpty);
    });
  });

  group('TerminalRepository', () {
    test('finds a terminal by location', () async {
      await db.terminals.put(
        Terminal(id: 't1', location: 'Dhaka', purchasedAt: t0),
      );
      expect(db.terminals.atLocation('Dhaka')!.id, 't1');
      expect(db.terminals.atLocation('Bogura'), isNull);
    });
  });

  group('RouteStateRepository', () {
    test('is keyed by route id', () async {
      await db.routeStates.put(
        RouteState(routeId: 'R05', demandRemainingT: 400, updatedAt: t0),
      );
      await db.routeStates.put(
        RouteState(routeId: 'R05', demandRemainingT: 390, updatedAt: t0),
      );
      expect(db.routeStates.count, 1);
      expect(db.routeStates.get('R05')!.demandRemainingT, 390);
    });
  });

  group('TripRepository', () {
    DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

    test('unsettled lists only open trips, earliest arrival first', () async {
      await db.trips.putAll([
        sampleTrip(id: 'late', arriveAt: at(30)),
        sampleTrip(id: 'done', arriveAt: at(5), settled: true),
        sampleTrip(id: 'early', arriveAt: at(10)),
      ]);
      expect(db.trips.unsettled().map((t) => t.id), ['early', 'late']);
    });

    test('dueAt returns arrived trips in settle order', () async {
      await db.trips.putAll([
        sampleTrip(id: 'c', arriveAt: at(40)),
        sampleTrip(id: 'a', arriveAt: at(10)),
        sampleTrip(id: 'b', arriveAt: at(20)),
        sampleTrip(id: 'old', arriveAt: at(1), settled: true),
      ]);
      expect(db.trips.dueAt(at(25)).map((t) => t.id), ['a', 'b']);
      expect(db.trips.dueAt(at(40)).map((t) => t.id), ['a', 'b', 'c']);
      expect(db.trips.dueAt(at(5)), isEmpty);
    });

    test('dueAt breaks arrival ties by departure then id', () async {
      Trip trip(String id, int departMin) => Trip(
        id: id,
        vehicleId: 'v',
        routeId: 'R01',
        cargo: 'Rice',
        loadT: 1,
        departAt: at(departMin),
        arriveAt: at(60),
        revenue: 0,
        costs: const TripCosts(
          energy: 0,
          toll: 0,
          crew: 0,
          maintenance: 0,
          fines: 0,
          accident: 0,
        ),
      );
      await db.trips.putAll([trip('z', 0), trip('b', 10), trip('a', 10)]);
      expect(db.trips.dueAt(at(60)).map((t) => t.id), ['z', 'a', 'b']);
    });

    test('activeFor finds the open trip of a vehicle', () async {
      await db.trips.putAll([
        sampleTrip(id: 'open'),
        sampleTrip(id: 'closed', settled: true),
      ]);
      expect(db.trips.activeFor('v1')!.id, 'open');
      expect(db.trips.activeFor('nobody'), isNull);
    });

    test('settling a trip removes it from unsettled', () async {
      final trip = sampleTrip();
      await db.trips.put(trip);
      await db.trips.put(trip.copyWith(settled: true));
      expect(db.trips.count, 1);
      expect(db.trips.unsettled(), isEmpty);
    });

    test('forVehicle filters', () async {
      await db.trips.putAll([sampleTrip(id: 'a'), sampleTrip(id: 'b')]);
      expect(db.trips.forVehicle('v1'), hasLength(2));
      expect(db.trips.forVehicle('v2'), isEmpty);
    });
  });

  test('clearAll erases the whole save', () async {
    await db.company.save(Company(name: 'A', cash: 1, createdAt: t0));
    await db.vehicles.put(Vehicle(id: 'v1', tier: 1, purchasedAt: t0));
    await db.terminals.put(
      Terminal(id: 't', location: 'Dhaka', purchasedAt: t0),
    );
    await db.routeStates.put(
      RouteState(routeId: 'R01', demandRemainingT: 1, updatedAt: t0),
    );
    await db.trips.put(sampleTrip());

    await db.clearAll();

    expect(db.company.exists, false);
    expect(db.vehicles.count, 0);
    expect(db.terminals.count, 0);
    expect(db.routeStates.count, 0);
    expect(db.trips.count, 0);
  });

  group('newId', () {
    test('starts with the prefix and is unique', () {
      final ids = List.generate(2000, (_) => newId('veh'));
      expect(ids.every((id) => id.startsWith('veh_')), true);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('is deterministic for a fixed time and random', () {
      final now = DateTime.utc(2026, 1, 1);
      expect(
        newId('trip', now: now, random: Random(1)),
        newId('trip', now: now, random: Random(1)),
      );
    });
  });
}
