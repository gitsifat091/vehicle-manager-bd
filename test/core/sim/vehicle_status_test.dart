import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/sim/vehicle_status.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../../support/sim_support.dart';

void main() {
  final idle = Vehicle(id: 'v1', tier: 4, purchasedAt: t0);

  Trip tripFor(
    String vehicleId, {
    Duration length = const Duration(minutes: 10),
  }) {
    return Trip(
      id: 'trip_1',
      vehicleId: vehicleId,
      vehicleTier: 4,
      routeId: 'R01',
      cargo: 'General dry',
      loadT: 1.5,
      departAt: t0,
      arriveAt: t0.add(length),
      revenue: 1,
      costs: const TripCosts(
        energy: 0,
        toll: 0,
        crew: 0,
        maintenance: 0,
        fines: 0,
        accident: 0,
      ),
    );
  }

  group('Trip.progressAt', () {
    final trip = tripFor('v1');

    test('0 at departure, 1 at arrival, linear between', () {
      expect(trip.progressAt(t0), 0);
      expect(trip.progressAt(t0.add(const Duration(minutes: 5))), 0.5);
      expect(trip.progressAt(t0.add(const Duration(minutes: 10))), 1);
    });

    test('stays inside 0 to 1 before departure and after arrival', () {
      expect(trip.progressAt(t0.subtract(const Duration(minutes: 3))), 0);
      expect(trip.progressAt(t0.add(const Duration(hours: 2))), 1);
    });

    test('a trip with no length counts as arrived', () {
      expect(tripFor('v1', length: Duration.zero).progressAt(t0), 1);
    });
  });

  group('vehicleActivity', () {
    test('an unassigned vehicle is idle', () {
      final a = vehicleActivity(vehicle: idle, activeTrip: null, now: t0);
      expect(a.status, VehicleStatus.idle);
      expect(a.progress, 0);
    });

    test('with an unsettled trip it is on the road, with progress', () {
      final vehicle = assignedVehicle(id: 'v1');
      final a = vehicleActivity(
        vehicle: vehicle,
        activeTrip: tripFor('v1'),
        now: t0.add(const Duration(minutes: 2, seconds: 30)),
      );
      expect(a.status, VehicleStatus.onTheRoad);
      expect(a.progress, 0.25);
      expect(a.trip!.id, 'trip_1');
    });

    test(
      'a trip that arrived but is not yet settled still shows as arriving',
      () {
        final a = vehicleActivity(
          vehicle: assignedVehicle(id: 'v1'),
          activeTrip: tripFor('v1'),
          now: t0.add(const Duration(minutes: 11)),
        );
        expect(a.status, VehicleStatus.onTheRoad);
        expect(a.progress, 1);
      },
    );

    test('assigned with a future availableAt waits for demand until then', () {
      final until = t0.add(const Duration(minutes: 12));
      final a = vehicleActivity(
        vehicle: assignedVehicle(availableAt: until),
        activeTrip: null,
        now: t0,
      );
      expect(a.status, VehicleStatus.waitingForDemand);
      expect(a.until, until);
    });

    test('assigned and free to go is ready to dispatch', () {
      final a = vehicleActivity(
        vehicle: assignedVehicle(availableAt: t0),
        activeTrip: null,
        now: t0.add(const Duration(seconds: 1)),
      );
      expect(a.status, VehicleStatus.readyToDispatch);
    });

    test('the trip wins over the waiting time', () {
      final a = vehicleActivity(
        vehicle: assignedVehicle(
          id: 'v1',
          availableAt: t0.add(const Duration(hours: 1)),
        ),
        activeTrip: tripFor('v1'),
        now: t0,
      );
      expect(a.status, VehicleStatus.onTheRoad);
    });
  });
}
