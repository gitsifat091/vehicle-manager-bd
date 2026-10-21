import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';

import '../test_config.dart';

/// Golden values from docs/economy_model.xlsx, default config.
/// Each is expected to match within 1 Taka.
void main() {
  final config = loadDefaultConfig();

  TripQuote quote(int tier, String routeId, String cargo, {double over = 0}) {
    return quoteTrip(
      config: config,
      vehicle: config.vehicleByTier(tier),
      route: config.routeById(routeId),
      cargo: config.cargoByName(cargo),
      overloadT: over,
    );
  }

  group('golden trips', () {
    test('Tier 6 Jamuna Open, R05, General dry', () {
      final q = quote(6, 'R05', 'General dry');
      expect(q.revenue, closeTo(36375, 1));
      expect(q.profit, closeTo(23995, 1));
      expect(q.tripGameHours, closeTo(9.25, 0.001));
    });

    test('Tier 6 cost parts, R05, General dry', () {
      final q = quote(6, 'R05', 'General dry');
      expect(q.energy, closeTo(7500, 0.01));
      expect(q.toll, 800);
      expect(q.crew, closeTo(1480, 0.01));
      expect(q.maintenance, closeTo(1000, 0.01));
      expect(q.expectedFines, 0);
      expect(q.expectedAccident, closeTo(1600, 0.01));
      expect(q.totalCost, closeTo(12380, 0.01));
      expect(q.margin, closeTo(23995 / 36375, 0.0001));
    });

    test('Tier 4 Sathi Plus, R01, General dry', () {
      final q = quote(4, 'R01', 'General dry');
      expect(q.revenue, closeTo(2693, 1));
      expect(q.profit, closeTo(2106, 1));
    });

    test('Tier 3 Tuntuni Mini, R01, Parcels', () {
      final q = quote(3, 'R01', 'Parcels');
      expect(q.revenue, closeTo(2308, 1));
      expect(q.profit, closeTo(1831, 1));
    });

    test('Tier 6, R05, Rice, 12 t overload', () {
      // 12 t over the 10 t legal payload gives 22 t, the max load.
      final q = quote(6, 'R05', 'Rice', over: 12);
      expect(q.loadT, 22);
      expect(q.revenue, closeTo(80025, 1));
      expect(q.profit, closeTo(35165, 1));
    });

    test('Tier 6, R05, Rice, 12 t overload cost parts', () {
      final q = quote(6, 'R05', 'Rice', over: 12);
      expect(q.overloadRatio, closeTo(1.2, 1e-9));
      expect(q.energy, closeTo(10200, 0.01));
      expect(q.maintenance, closeTo(2800, 0.01));
      // 2 weighbridges x 0.35 x (5000 + 2000 x 12 t)
      expect(q.expectedFines, closeTo(20300, 0.01));
      expect(q.fineIfCaught, closeTo(29000, 0.01));
      expect(q.accidentChance, closeTo(0.029, 1e-9));
      expect(q.expectedAccident, closeTo(9280, 0.01));
    });

    test('Tier 6 Jamuna Open, R11 (ferry), General dry', () {
      final q = quote(6, 'R11', 'General dry');
      expect(q.revenue, closeTo(38925, 1));
      expect(q.profit, closeTo(24197, 1));
      expect(q.toll, 1460);
      expect(q.tripGameHours, closeTo(14.75, 0.001));
    });

    test('Tier 1 on R05 is rejected: not allowed on highway', () {
      final vehicle = config.vehicleByTier(1);
      final route = config.routeById('R05');
      final rejection = checkTripEligibility(vehicle: vehicle, route: route);
      expect(rejection, isNotNull);
      expect(rejection!.reason, TripRejectionReason.vehicleNotAllowedOnHighway);
      expect(
        () => quote(1, 'R05', 'General dry'),
        throwsA(isA<TripRejectedException>()),
      );
    });
  });

  test('rounded getters round to whole Taka', () {
    final q = quote(4, 'R01', 'General dry');
    expect(q.revenueTk, 2693);
    expect(q.profitTk, 2106);
  });
}
