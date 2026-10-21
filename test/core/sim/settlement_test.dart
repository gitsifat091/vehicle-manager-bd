import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/core/sim/settlement.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../../support/sim_support.dart';
import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();

  /// A dispatched trip as the economy engine quotes it.
  Trip tripFor(
    EconomyConfig cfg,
    int tier,
    String routeId,
    String cargo, {
    double over = 0,
  }) {
    final quote = quoteTrip(
      config: cfg,
      vehicle: cfg.vehicleByTier(tier),
      route: cfg.routeById(routeId),
      cargo: cfg.cargoByName(cargo),
      overloadT: over,
    );
    return Trip(
      id: 'trip_1',
      vehicleId: 'v1',
      vehicleTier: tier,
      routeId: routeId,
      cargo: cargo,
      loadT: quote.loadT,
      departAt: t0,
      arriveAt: t0.add(const Duration(minutes: 9)),
      revenue: quote.revenueTk,
      costs: TripCosts.fromQuote(quote),
    );
  }

  group('weighbridges and accident', () {
    // Tier 6, R05, 12 t over: two weighbridges at 35 percent, a fine of
    // 5000 + 2000 x 12 = 29,000 each, accident chance 2.9 percent, cost 320,000.
    final overloaded = tripFor(config, 6, 'R05', 'Rice', over: 12);

    test('each weighbridge is rolled separately, then the accident', () {
      final dice = ScriptedRandom([0.10, 0.50, 0.01]);
      final result = settleTrip(config: config, trip: overloaded, random: dice);
      expect(result.weighbridgesCaught, 1);
      expect(result.hadAccident, true);
      expect(result.trip.costs.fines, 29000);
      expect(result.trip.costs.accident, 320000);
      expect(result.trip.settled, true);
      expect(dice.draws, 3);
    });

    test('both weighbridges can catch the truck', () {
      final result = settleTrip(
        config: config,
        trip: overloaded,
        random: ScriptedRandom([0.0, 0.34, 0.9]),
      );
      expect(result.weighbridgesCaught, 2);
      expect(result.trip.costs.fines, 58000);
      expect(result.hadAccident, false);
      expect(result.trip.costs.accident, 0);
    });

    test('a roll equal to the chance does not catch', () {
      final result = settleTrip(
        config: config,
        trip: overloaded,
        random: ScriptedRandom([0.35, 0.35, 0.5]),
      );
      expect(result.weighbridgesCaught, 0);
      expect(result.hadAccident, false);
    });

    test('keeps revenue and the dispatch costs that are not rolled', () {
      final result = settleTrip(
        config: config,
        trip: overloaded,
        random: ScriptedRandom([0.9, 0.9, 0.9]),
      );
      expect(result.trip.revenue, overloaded.revenue);
      expect(result.trip.costs.energy, overloaded.costs.energy);
      expect(result.trip.costs.toll, overloaded.costs.toll);
      expect(result.trip.costs.crew, overloaded.costs.crew);
      expect(result.trip.costs.maintenance, overloaded.costs.maintenance);
      expect(result.trip.id, overloaded.id);
      expect(result.trip.arriveAt, overloaded.arriveAt);
    });

    test('a trip that is not overloaded rolls only the accident', () {
      final trip = tripFor(config, 6, 'R05', 'General dry');
      final dice = ScriptedRandom([0.5]);
      final result = settleTrip(config: config, trip: trip, random: dice);
      expect(dice.draws, 1);
      expect(result.trip.costs.fines, 0);
      expect(result.hadAccident, false);
    });

    test(
      'an overloaded trip on a route without weighbridges is never fined',
      () {
        // R10 has no weighbridges.
        final trip = tripFor(config, 6, 'R10', 'Rice', over: 12);
        final dice = ScriptedRandom([0.0]);
        final result = settleTrip(config: config, trip: trip, random: dice);
        expect(dice.draws, 1);
        expect(result.trip.costs.fines, 0);
      },
    );

    test('the accident costs the price share of the vehicle', () {
      final trip = tripFor(config, 4, 'R01', 'General dry');
      final result = settleTrip(
        config: config,
        trip: trip,
        random: ScriptedRandom([0.0]),
      );
      // 1,300,000 x 0.1
      expect(result.trip.costs.accident, 130000);
    });

    test('chance 100 percent always catches and always crashes', () {
      final sure = editedConfig((j) {
        j['settings']['weighbridgeCheckChance'] = 1;
        j['settings']['accidentChancePer100Km'] = 1000;
      });
      final trip = tripFor(sure, 6, 'R05', 'Rice', over: 12);
      final result = settleTrip(config: sure, trip: trip, random: Random(1));
      expect(result.weighbridgesCaught, 2);
      expect(result.hadAccident, true);
    });

    test('chance 0 never catches and never crashes', () {
      final never = editedConfig((j) {
        j['settings']['weighbridgeCheckChance'] = 0;
        j['settings']['accidentChancePer100Km'] = 0;
      });
      final trip = tripFor(never, 6, 'R05', 'Rice', over: 12);
      for (var seed = 0; seed < 20; seed++) {
        final result = settleTrip(
          config: never,
          trip: trip,
          random: Random(seed),
        );
        expect(result.weighbridgesCaught, 0);
        expect(result.hadAccident, false);
      }
    });
  });

  group('a fixed seed', () {
    final overloaded = tripFor(config, 6, 'R05', 'Rice', over: 12);

    test('gives the same result every time', () {
      final a = settleTrip(
        config: config,
        trip: overloaded,
        random: Random(2026),
      );
      final b = settleTrip(
        config: config,
        trip: overloaded,
        random: Random(2026),
      );
      expect(a.trip, b.trip);
      expect(a.weighbridgesCaught, b.weighbridgesCaught);
      expect(a.hadAccident, b.hadAccident);
    });

    test('matches an independent replay of the dice order', () {
      final settleRandom = Random(7);
      final replay = Random(7);
      for (var i = 0; i < 200; i++) {
        final result = settleTrip(
          config: config,
          trip: overloaded,
          random: settleRandom,
        );
        // Order: weighbridge 1, weighbridge 2, then the accident.
        var caught = 0;
        if (replay.nextDouble() < 0.35) caught++;
        if (replay.nextDouble() < 0.35) caught++;
        final accident = replay.nextDouble() < 0.029;
        expect(result.weighbridgesCaught, caught, reason: 'trip $i');
        expect(result.hadAccident, accident, reason: 'trip $i');
        expect(result.trip.costs.fines, caught * 29000);
        expect(result.trip.costs.accident, accident ? 320000 : 0);
      }
    });

    test('over many trips the fine rate is close to the check chance', () {
      final random = Random(99);
      var caught = 0;
      const trips = 4000;
      for (var i = 0; i < trips; i++) {
        caught += settleTrip(
          config: config,
          trip: overloaded,
          random: random,
        ).weighbridgesCaught;
      }
      final rate = caught / (trips * 2);
      expect(rate, closeTo(0.35, 0.03));
    });
  });

  test(
    'a trip whose vehicle is no longer in the config settles as dispatched',
    () {
      final trip = tripFor(config, 4, 'R01', 'General dry');
      final orphan = Trip(
        id: trip.id,
        vehicleId: trip.vehicleId,
        vehicleTier: 0,
        routeId: trip.routeId,
        cargo: trip.cargo,
        loadT: trip.loadT,
        departAt: trip.departAt,
        arriveAt: trip.arriveAt,
        revenue: trip.revenue,
        costs: trip.costs,
      );
      final dice = ScriptedRandom([]);
      final result = settleTrip(config: config, trip: orphan, random: dice);
      expect(dice.draws, 0);
      expect(result.trip.settled, true);
      expect(result.trip.costs, orphan.costs);
    },
  );
}
