import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/trip_formulas.dart' as f;
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';

import '../test_config.dart';

RouteSpec testRoute({
  String id = 'T',
  double distanceKm = 20,
  HaulType haulType = HaulType.line,
  String crossing = 'None',
}) => RouteSpec(
  id: id,
  from: 'A',
  to: 'B',
  distanceKm: distanceKm,
  haulType: haulType,
  crossing: crossing,
  weighbridges: 0,
  extraDelayGameH: 0,
  dailyDemandT: 10,
);

void main() {
  final config = loadDefaultConfig();
  final general = config.cargoByName('General dry');

  TripQuote quote(int tier, String routeId, {double over = 0}) => quoteTrip(
    config: config,
    vehicle: config.vehicleByTier(tier),
    route: config.routeById(routeId),
    cargo: general,
    overloadT: over,
  );

  group('overload', () {
    test('is capped at the vehicle max load', () {
      // Tier 6: legal 10 t, max 22 t. Asking for 50 t over still carries 22 t.
      final q = quote(6, 'R05', over: 50);
      expect(q.loadT, 22);
      expect(q.tonsOver, 12);
      expect(q.overloadRatio, closeTo(1.2, 1e-9));
    });

    test('is unchanged below the cap', () {
      final q = quote(6, 'R05', over: 5);
      expect(q.loadT, 15);
      expect(q.tonsOver, 5);
      expect(q.overloadRatio, closeTo(0.5, 1e-9));
    });

    test('tanker cannot overload', () {
      // Tier 10: legal payload equals max load.
      final q = quote(10, 'R05', over: 8);
      expect(q.loadT, 12.75);
      expect(q.tonsOver, 0);
      expect(q.overloadRatio, 0);
      expect(q.expectedFines, 0);
      expect(q.fineIfCaught, 0);
    });

    test('no fine when not overloaded, even with weighbridges', () {
      expect(quote(6, 'R05').expectedFines, 0);
    });

    test('no expected fine on a route without weighbridges', () {
      // R10 has 0 weighbridges.
      final q = quote(6, 'R10', over: 12);
      expect(q.fineIfCaught, greaterThan(0));
      expect(q.expectedFines, 0);
    });

    test('raises energy, maintenance and accident chance', () {
      final base = quote(6, 'R05');
      final over = quote(6, 'R05', over: 5);
      expect(over.energy, greaterThan(base.energy));
      expect(over.maintenance, greaterThan(base.maintenance));
      expect(over.accidentChance, greaterThan(base.accidentChance));
    });

    test('negative overload is rejected', () {
      final rejection = checkTripEligibility(
        vehicle: config.vehicleByTier(6),
        route: config.routeById('R05'),
        overloadT: -1,
      );
      expect(rejection!.reason, TripRejectionReason.negativeOverload);
    });
  });

  group('Local hauls', () {
    test('double the driven distance', () {
      final local = config.routeById('R01');
      expect(local.distanceKm, 15);
      expect(f.drivenKm(local), 30);
      expect(quote(4, 'R01').drivenKm, 30);
    });

    test('Line hauls drive the one-way distance', () {
      expect(f.drivenKm(config.routeById('R05')), 250);
    });

    test('double the toll', () {
      // No local route in the default config has a crossing, so build one.
      final vehicle = config.vehicleByTier(6);
      final local = testRoute(
        haulType: HaulType.local,
        crossing: 'Padma Bridge',
      );
      final line = testRoute(haulType: HaulType.line, crossing: 'Padma Bridge');
      expect(f.tollCost(config: config, vehicle: vehicle, route: local), 5600);
      expect(f.tollCost(config: config, vehicle: vehicle, route: line), 2800);
    });

    test('trip time uses the doubled distance', () {
      // Tier 4: 30 km / 50 km/h + 0.5 h load + 0.3 h delay.
      expect(quote(4, 'R01').tripGameHours, closeTo(1.4, 1e-9));
    });

    test('revenue uses the one-way distance', () {
      final revenue = f.revenue(
        settings: config.settings,
        vehicle: config.vehicleByTier(4),
        route: config.routeById('R01'),
        cargo: general,
        loadT: 1.5,
      );
      // 1.5 t x (300 + 8.5 x 15) x 1 x 2.8 x 1.5
      expect(revenue, closeTo(2693.25, 1e-9));
    });
  });

  group('eligibility', () {
    test('tier 1 and 2 are rejected on every Line route', () {
      for (final tier in [1, 2]) {
        final lineRoutes = config.routes.where(
          (r) => r.haulType == HaulType.line,
        );
        for (final route in lineRoutes) {
          final rejection = checkTripEligibility(
            vehicle: config.vehicleByTier(tier),
            route: route,
          );
          expect(
            rejection?.reason,
            TripRejectionReason.vehicleNotAllowedOnHighway,
            reason: 'tier $tier on ${route.id}',
          );
        }
      }
    });

    test('tier 1 and 2 are rejected on a Local route with a crossing', () {
      final rejection = checkTripEligibility(
        vehicle: config.vehicleByTier(2),
        route: testRoute(haulType: HaulType.local, crossing: 'Padma Bridge'),
      );
      expect(rejection!.reason, TripRejectionReason.vehicleNotAllowedOnHighway);
    });

    test('tier 1 and 2 are allowed on Local routes without a crossing', () {
      for (final tier in [1, 2]) {
        expect(
          checkTripEligibility(
            vehicle: config.vehicleByTier(tier),
            route: config.routeById('R01'),
          ),
          isNull,
        );
      }
    });

    test('tier 1 pedal van has no energy cost and pays no toll', () {
      final q = quote(1, 'M01');
      expect(q.toll, 0);
      expect(q.energy, 0);
    });

    test('tier 2 uses its other energy cost per km', () {
      // R01 Local: 30 km x 1.5 Tk/km.
      expect(quote(2, 'R01').energy, closeTo(45, 1e-9));
    });

    test('Line haul over 400 km is rejected with a clear reason', () {
      final route = testRoute(id: 'LONG', distanceKm: 401);
      final vehicle = config.vehicleByTier(6);
      final rejection = checkTripEligibility(vehicle: vehicle, route: route);
      expect(rejection!.reason, TripRejectionReason.lineHaulTooLong);
      expect(rejection.message, contains('400'));
      expect(
        () => quoteTrip(
          config: config,
          vehicle: vehicle,
          route: route,
          cargo: general,
        ),
        throwsA(isA<TripRejectedException>()),
      );
    });

    test('Line haul of exactly 400 km is allowed', () {
      expect(
        checkTripEligibility(
          vehicle: config.vehicleByTier(6),
          route: testRoute(distanceKm: 400),
        ),
        isNull,
      );
    });

    test('Local haul over 400 km is not limited', () {
      expect(
        checkTripEligibility(
          vehicle: config.vehicleByTier(6),
          route: testRoute(distanceKm: 500, haulType: HaulType.local),
        ),
        isNull,
      );
    });

    test('every default route is allowed for tier 6', () {
      for (final route in config.routes) {
        expect(
          checkTripEligibility(vehicle: config.vehicleByTier(6), route: route),
          isNull,
          reason: route.id,
        );
      }
    });
  });

  group('quote totals', () {
    test('total cost is the sum of its parts and profit is the remainder', () {
      final q = quote(6, 'R05', over: 6);
      final parts =
          q.energy +
          q.toll +
          q.crew +
          q.maintenance +
          q.expectedFines +
          q.expectedAccident;
      expect(q.totalCost, closeTo(parts, 1e-9));
      expect(q.profit, closeTo(q.revenue - parts, 1e-9));
    });

    test('margin is profit over revenue', () {
      final q = quote(4, 'R01');
      expect(q.margin, closeTo(q.profit / q.revenue, 1e-12));
    });

    test('accident chance never exceeds 1', () {
      final chance = f.accidentChance(
        settings: config.settings,
        drivenKm: 1e9,
        overloadRatio: 5,
      );
      expect(chance, 1);
    });
  });
}
