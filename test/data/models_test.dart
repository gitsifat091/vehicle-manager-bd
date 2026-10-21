import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../core/test_config.dart';
import 'fixtures.dart';

void main() {
  final config = loadDefaultConfig();

  group('Company', () {
    test('newGame starts with the config starting cash', () {
      final c = Company.newGame(config: config, name: 'Sifat Ltd', now: t0);
      expect(c.cash, 1500000);
      expect(c.completedTrips, 0);
      expect(c.createdAt, t0);
    });

    test('copyWith keeps createdAt', () {
      final c = Company(name: 'A', cash: 10, createdAt: t0);
      final d = c.copyWith(cash: 5, completedTrips: 2);
      expect(d.cash, 5);
      expect(d.completedTrips, 2);
      expect(d.createdAt, t0);
      expect(d.name, 'A');
    });

    test('stores times as UTC', () {
      final local = DateTime(2026, 1, 1, 10);
      expect(
        Company(name: 'A', cash: 0, createdAt: local).createdAt.isUtc,
        true,
      );
    });

    group('permits', () {
      test('start empty', () {
        expect(Company(name: 'A', cash: 1, createdAt: t0).permits, isEmpty);
      });

      test('copyWith keeps them when something else changes', () {
        final c = Company(
          name: 'A',
          cash: 10,
          createdAt: t0,
          permits: {'light'},
        );
        final d = c.copyWith(cash: 5, completedTrips: 3);
        expect(d.permits, {'light'});
      });

      test('copyWith can add one', () {
        final c = Company(name: 'A', cash: 10, createdAt: t0);
        final d = c.copyWith(permits: {...c.permits, 'heavy'});
        expect(d.permits, {'heavy'});
        expect(c.permits, isEmpty);
      });

      test('cannot be changed in place or through the set that was passed', () {
        final source = {'light'};
        final c = Company(name: 'A', cash: 1, createdAt: t0, permits: source);
        source.add('hazmat');
        expect(c.permits, {'light'});
        expect(() => c.permits.add('heavy'), throwsUnsupportedError);
      });

      test('count in equality, whatever the order', () {
        Company make(Set<String> p) =>
            Company(name: 'A', cash: 1, createdAt: t0, permits: p);
        expect(make({'light', 'heavy'}), make({'heavy', 'light'}));
        expect(
          make({'light', 'heavy'}).hashCode,
          make({'heavy', 'light'}).hashCode,
        );
        expect(make({'light'}) == make({'heavy'}), false);
        expect(make({'light'}) == make({}), false);
      });
    });
  });

  group('Trip.progressAt', () {
    test('is linear between departure and arrival, and clamped outside', () {
      final trip = sampleTrip(); // 9 minutes from t0
      expect(trip.progressAt(t0), 0);
      expect(
        trip.progressAt(t0.add(const Duration(minutes: 3))),
        closeTo(1 / 3, 1e-9),
      );
      expect(trip.progressAt(t0.add(const Duration(minutes: 9))), 1);
      expect(trip.progressAt(t0.subtract(const Duration(minutes: 1))), 0);
      expect(trip.progressAt(t0.add(const Duration(days: 1))), 1);
    });
  });

  group('Vehicle', () {
    test('starts unassigned', () {
      final v = Vehicle(id: 'v1', tier: 4, purchasedAt: t0);
      expect(v.isAssigned, false);
      expect(v.overloadT, 0);
    });

    test('withAssignment and withoutAssignment', () {
      final v = Vehicle(id: 'v1', tier: 6, purchasedAt: t0);
      final a = v.withAssignment(
        routeId: 'R05',
        cargoName: 'Rice',
        overloadT: 4,
        availableAt: t0,
      );
      expect(a.isAssigned, true);
      expect(a.assignedRouteId, 'R05');
      expect(a.assignedCargo, 'Rice');
      expect(a.overloadT, 4);
      expect(a.availableAt, t0);
      expect(a.id, 'v1');
      expect(a.withoutAssignment(), v);
    });

    test('route and cargo must be set together', () {
      expect(
        () =>
            Vehicle(id: 'v1', tier: 6, purchasedAt: t0, assignedRouteId: 'R05'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('RouteState', () {
    test('initial holds the full daily demand', () {
      final s = RouteState.initial(config.routeById('R05'), t0);
      expect(s.routeId, 'R05');
      expect(s.demandRemainingT, 400);
      expect(s.updatedAt, t0);
    });
  });

  group('Trip', () {
    test('profit is revenue minus total costs', () {
      final t = sampleTrip();
      expect(t.costs.total, 12380);
      expect(t.profit, 23995);
    });

    test('hasArrivedBy is inclusive of the arrival instant', () {
      final t = sampleTrip();
      expect(
        t.hasArrivedBy(t.arriveAt.subtract(const Duration(seconds: 1))),
        false,
      );
      expect(t.hasArrivedBy(t.arriveAt), true);
      expect(t.hasArrivedBy(t.arriveAt.add(const Duration(hours: 1))), true);
    });

    test('copyWith settles without changing the rest', () {
      final t = sampleTrip();
      final s = t.copyWith(settled: true);
      expect(s.settled, true);
      expect(s.id, t.id);
      expect(s.arriveAt, t.arriveAt);
      expect(s.costs, t.costs);
    });

    test('TripCosts.fromQuote rounds each part of a quote', () {
      final quote = quoteTrip(
        config: config,
        vehicle: config.vehicleByTier(6),
        route: config.routeById('R05'),
        cargo: config.cargoByName('General dry'),
      );
      final costs = TripCosts.fromQuote(quote);
      expect(costs.energy, 7500);
      expect(costs.toll, 800);
      expect(costs.crew, 1480);
      expect(costs.maintenance, 1000);
      expect(costs.fines, 0);
      expect(costs.accident, 1600);
      expect(costs.total, 12380);
    });
  });
}
