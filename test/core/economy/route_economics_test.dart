import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/route_economics.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';

import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();
  final gmpm = config.settings.gameMinutesPerRealMinute;

  RouteEconomics economics(int tier, String routeId, String cargo) =>
      routeEconomics(
        config: config,
        vehicle: config.vehicleByTier(tier),
        route: config.routeById(routeId),
        cargo: config.cargoByName(cargo),
      );

  group('one vehicle on one route', () {
    // Golden trip from CLAUDE.md: profit 23,995 per trip, 9.25 game hours.
    test(
      'Tier 6 on R05: profit per hour and payback follow the golden trip',
      () {
        final e = economics(6, 'R05', 'General dry');
        expect(e.quote.profit, closeTo(23995, 1));
        expect(e.tripRealHours, closeTo(9.25 / gmpm, 1e-9));
        expect(e.profitPerRealHour, closeTo(23995 / (9.25 / gmpm), 10));
        expect(
          e.paybackRealHours,
          closeTo(e.vehicle.priceTk / (23995 / (9.25 / gmpm)), 0.001),
        );
      },
    );

    test('Tier 4 on R01: tons per game day and how many the route holds', () {
      // Local haul: 30 km at 50 km/h + 0.5 h loading + 0.3 h delay = 1.4 h,
      // 1.5 t legal payload each trip.
      final e = economics(4, 'R01', 'General dry');
      expect(e.quote.tripGameHours, closeTo(1.4, 1e-9));
      expect(e.quote.loadT, 1.5);
      expect(e.tonsPerGameDay, closeTo(24 / 1.4 * 1.5, 1e-9));
      expect(e.vehiclesRouteHolds, closeTo(60 / (24 / 1.4 * 1.5), 1e-9));
    });

    test('a trip that is not allowed throws', () {
      // Tier 1 runs only M01 and M02.
      expect(
        () => economics(1, 'R05', 'Market goods'),
        throwsA(isA<TripRejectedException>()),
      );
    });

    test('a losing trip has no payback', () {
      final e = RouteEconomics(
        vehicle: config.vehicleByTier(4),
        route: config.routeById('R01'),
        cargo: config.cargoByName('General dry'),
        quote: const TripQuote(
          vehicleTier: 4,
          routeId: 'R01',
          cargoName: 'General dry',
          loadT: 1.5,
          tonsOver: 0,
          overloadRatio: 0,
          drivenKm: 30,
          tripGameHours: 1.4,
          revenue: 100,
          energy: 200,
          toll: 0,
          crew: 0,
          maintenance: 0,
          expectedFines: 0,
          expectedAccident: 0,
          fineIfCaught: 0,
          accidentChance: 0,
          accidentCostIfHit: 0,
        ),
        gameMinutesPerRealMinute: gmpm,
      );
      expect(e.profitPerRealHour, lessThan(0));
      expect(e.paybackRealHours, isNull);
    });
  });

  group('choosing the cargo', () {
    test('allCargoOn lists only cargo the vehicle may carry, in order', () {
      final vehicle = config.vehicleByTier(4);
      final route = config.routeById('R01');
      final all = allCargoOn(config: config, vehicle: vehicle, route: route);
      final expected = [
        for (final c in config.cargo)
          if (c.allowedTiers.contains(4)) c.name,
      ];
      expect(all.map((e) => e.cargo.name), expected);
      expect(all, isNotEmpty);
    });

    test('allCargoOn is empty on a route the vehicle cannot run', () {
      final all = allCargoOn(
        config: config,
        vehicle: config.vehicleByTier(1),
        route: config.routeById('R05'),
      );
      expect(all, isEmpty);
    });

    test('bestCargoOn picks the highest profit per hour', () {
      for (final vehicle in config.vehicles) {
        for (final route in config.routes) {
          final all = allCargoOn(
            config: config,
            vehicle: vehicle,
            route: route,
          );
          final best = bestCargoOn(
            config: config,
            vehicle: vehicle,
            route: route,
          );
          final where = 'tier ${vehicle.tier} on ${route.id}';
          if (all.isEmpty) {
            expect(best, isNull, reason: where);
            continue;
          }
          for (final e in all) {
            expect(
              best!.profitPerRealHour,
              greaterThanOrEqualTo(e.profitPerRealHour),
              reason: '$where, ${e.cargo.name}',
            );
          }
        }
      }
    });

    test('bestCargoPerRoute gives one entry per runnable route', () {
      final tier1 = bestCargoPerRoute(
        config: config,
        vehicle: config.vehicleByTier(1),
      );
      expect(tier1.map((e) => e.route.id), ['M01', 'M02']);

      final tier4 = bestCargoPerRoute(
        config: config,
        vehicle: config.vehicleByTier(4),
      );
      final runnable = [
        for (final r in config.routes)
          if (allCargoOn(
            config: config,
            vehicle: config.vehicleByTier(4),
            route: r,
          ).isNotEmpty)
            r.id,
      ];
      expect(tier4.map((e) => e.route.id), runnable);
    });
  });

  group('route demand', () {
    final sathiOnR01 = economics(4, 'R01', 'General dry');
    final r01 = config.routeById('R01');

    test('tonsPerGameDayByRoute adds up the fleet per route', () {
      final vanOnM01 = economics(1, 'M01', 'Market goods');
      final used = tonsPerGameDayByRoute([sathiOnR01, sathiOnR01, vanOnM01]);
      expect(used['R01'], closeTo(2 * sathiOnR01.tonsPerGameDay, 1e-9));
      expect(used['M01'], closeTo(vanOnM01.tonsPerGameDay, 1e-9));
      expect(used.containsKey('R05'), false);
      expect(tonsPerGameDayByRoute(const []), isEmpty);
    });

    test('an empty route has all its demand spare', () {
      final demand = RouteDemand(route: r01, usedTonsPerGameDay: 0);
      expect(demand.dailyDemandT, 60);
      expect(demand.spareTonsPerGameDay, 60);
      expect(demand.fits(sathiOnR01), true);
      // 60 t / 25.7 t a day: two Sathi Plus stay busy all day.
      expect(demand.vehiclesThatFit(sathiOnR01), 2);
    });

    test('two Sathi Plus leave too little for a third', () {
      final demand = RouteDemand(
        route: r01,
        usedTonsPerGameDay: 2 * sathiOnR01.tonsPerGameDay,
      );
      expect(
        demand.spareTonsPerGameDay,
        closeTo(60 - 2 * 24 / 1.4 * 1.5, 1e-9),
      );
      expect(demand.fits(sathiOnR01), false);
      expect(demand.vehiclesThatFit(sathiOnR01), 0);
    });

    test('exactly enough spare demand fits', () {
      final demand = RouteDemand(
        route: r01,
        usedTonsPerGameDay: 60 - sathiOnR01.tonsPerGameDay,
      );
      expect(demand.fits(sathiOnR01), true);
      expect(demand.vehiclesThatFit(sathiOnR01), 1);
    });

    test('spare demand never goes below zero', () {
      final demand = RouteDemand(route: r01, usedTonsPerGameDay: 90);
      expect(demand.spareTonsPerGameDay, 0);
      expect(demand.fits(sathiOnR01), false);
      expect(demand.vehiclesThatFit(sathiOnR01), 0);
    });
  });
}
