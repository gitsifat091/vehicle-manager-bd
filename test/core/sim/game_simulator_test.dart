import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/core/sim/dispatch.dart';
import 'package:vehicle_manager_bd/core/sim/game_simulator.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../../support/sim_support.dart';
import '../test_config.dart';

Duration secs(num s) => Duration(microseconds: (s * 1e6).round());

void main() {
  // Accidents off: every Tier 4 trip on R01 then earns exactly
  // 2693 - (338 + 112 + 60) = 2183 Taka.
  const profitPerTrip = 2183;
  final config = quietConfig();

  GameSimulator simulator({EconomyConfig? cfg, Random? random, int? maxSteps}) {
    return GameSimulator(
      config: cfg ?? config,
      random: random ?? Random(1),
      newId: counterIds(),
      maxStepsPerVehicle: maxSteps ?? GameSimulator.defaultMaxStepsPerVehicle,
    );
  }

  group('8 hours away', () {
    final world = worldOf(vehicles: [assignedVehicle()]);
    final now = t0.add(const Duration(hours: 8));
    final change = simulator().advance(world: world, now: now, turboSpeed: 1);

    test('repeats the Local haul back to back: 343 depart, 342 arrive', () {
      // A trip takes 84 s. Departures at 0, 84, ... 28728 s; the next would
      // be at 28812 s, after the 28800 s mark.
      expect(change.trips, hasLength(343));
      expect(change.settledTrips, hasLength(342));
    });

    test('pays every settled trip: cash and trip count', () {
      expect(change.cashAfter, 1500000 + 342 * profitPerTrip);
      expect(change.completedTripsAfter, 342);
      for (final trip in change.settledTrips) {
        expect(trip.revenue, 2693);
        expect(trip.profit, profitPerTrip);
      }
    });

    test('each trip departs at the previous arrival', () {
      final trips = [...change.trips]
        ..sort((a, b) => a.departAt.compareTo(b.departAt));
      expect(trips.first.departAt, t0);
      for (var i = 1; i < trips.length; i++) {
        expect(trips[i].departAt, trips[i - 1].arriveAt, reason: 'trip $i');
      }
    });

    test('settles in time order', () {
      final settled = change.settledTrips.toList();
      for (var i = 1; i < settled.length; i++) {
        expect(
          settled[i].arriveAt.isBefore(settled[i - 1].arriveAt),
          false,
          reason: 'trip $i',
        );
      }
    });

    test('leaves one trip on the road, arriving after now', () {
      final open = change.trips.where((t) => !t.settled).toList();
      expect(open, hasLength(1));
      expect(open.single.departAt, t0.add(secs(28728)));
      expect(open.single.arriveAt, t0.add(secs(28812)));
      expect(open.single.arriveAt.isAfter(now), true);
    });

    test('the vehicle is free at the last arrival', () {
      expect(change.vehicles, hasLength(1));
      expect(change.vehicles.single.availableAt, t0.add(secs(28728)));
    });

    test('uses 343 trips of the shared demand', () {
      // 343 x 1.5 t over 20 game days, far below the 60 t a day.
      expect(change.routeStates, hasLength(1));
      expect(change.routeStates.single.routeId, 'R01');
    });

    test('a second advance right after changes nothing', () {
      final next = applyChange(world, change);
      final again = simulator().advance(world: next, now: now, turboSpeed: 1);
      expect(again.isEmpty, true);
      expect(again.cashAfter, change.cashAfter);
    });

    test('catching up in one go equals ticking every 3 seconds', () {
      var ticking = world;
      var clock = t0;
      final sim = simulator();
      while (clock.isBefore(now)) {
        clock = clock.add(const Duration(seconds: 3));
        final step = sim.advance(world: ticking, now: clock, turboSpeed: 1);
        ticking = applyChange(ticking, step);
      }
      expect(ticking.company.cash, change.cashAfter);
      expect(ticking.company.completedTrips, change.completedTripsAfter);
    });
  });

  group('demand', () {
    test('runs out, the vehicle waits, and demand resets the next day', () {
      // 3 t a day and 1.5 t a trip: two trips per game day.
      final cfg = quietConfig((j) => setDemand(j, 'R01', 3));
      final world = worldOf(vehicles: [assignedVehicle()]);
      final sim = simulator(cfg: cfg);

      // 47 minutes: day 0 gives two trips, day 1 gives two more.
      final change = sim.advance(
        world: world,
        now: t0.add(const Duration(minutes: 47)),
        turboSpeed: 1,
      );
      final trips = [...change.trips]
        ..sort((a, b) => a.departAt.compareTo(b.departAt));
      expect(trips.map((t) => t.departAt.difference(t0).inSeconds), [
        0,
        84,
        1440, // the next game day starts at 24 min
        1524,
      ]);
      expect(trips.every((t) => t.loadT == 1.5), true);
      expect(change.settledTrips, hasLength(4));

      // Waiting for the third game day, which starts at 48 minutes.
      expect(change.vehicles.single.availableAt, t0.add(secs(2880)));
      expect(change.routeStates.single.demandRemainingT, 0);
    });

    test('departs again when the next day starts', () {
      final cfg = quietConfig((j) => setDemand(j, 'R01', 3));
      final sim = simulator(cfg: cfg);
      var world = worldOf(vehicles: [assignedVehicle()]);
      world = applyChange(
        world,
        sim.advance(
          world: world,
          now: t0.add(const Duration(minutes: 47)),
          turboSpeed: 1,
        ),
      );
      // Day 2 starts at 48 minutes (2880 s): two more trips fit before it ends.
      final change = sim.advance(
        world: world,
        now: t0.add(const Duration(minutes: 51)),
        turboSpeed: 1,
      );
      expect(change.trips.map((t) => t.departAt.difference(t0).inSeconds), [
        2880,
        2964,
      ]);
      expect(change.trips.every((t) => t.settled), true);
    });

    test('carries the last bit of demand with a smaller load', () {
      final cfg = quietConfig((j) => setDemand(j, 'R01', 2));
      final change = simulator(cfg: cfg).advance(
        world: worldOf(vehicles: [assignedVehicle()]),
        now: t0.add(const Duration(minutes: 5)),
        turboSpeed: 1,
      );
      final loads =
          ([...change.trips]..sort((a, b) => a.departAt.compareTo(b.departAt)))
              .map((t) => t.loadT)
              .toList();
      expect(loads, [1.5, 0.5]);
      expect(change.routeStates.single.demandRemainingT, 0);
    });

    test('two vehicles share the route demand in time order', () {
      final cfg = quietConfig((j) => setDemand(j, 'R01', 3));
      final world = worldOf(
        vehicles: [
          assignedVehicle(id: 'b'),
          assignedVehicle(id: 'a'),
        ],
      );
      final change = simulator(cfg: cfg).advance(
        world: world,
        now: t0.add(const Duration(seconds: 100)),
        turboSpeed: 1,
      );
      // Both depart at t0 and take 1.5 t each; the third departure at 84 s
      // finds nothing left.
      final departures = change.trips.where((t) => t.departAt == t0).toList();
      expect(departures.map((t) => t.vehicleId).toSet(), {'a', 'b'});
      expect(departures.map((t) => t.loadT), [1.5, 1.5]);
      expect(change.trips, hasLength(2));
      expect(change.vehicles.map((v) => v.availableAt).toSet(), {
        t0.add(const Duration(minutes: 24)),
      });
    });

    test('turbo speed makes trips shorter and more of them fit', () {
      final cfg = quietConfig((j) => setDemand(j, 'R01', 1000000));
      final slow = simulator(cfg: cfg).advance(
        world: worldOf(vehicles: [assignedVehicle()]),
        now: t0.add(const Duration(minutes: 10)),
        turboSpeed: 1,
      );
      final fast = simulator(cfg: cfg).advance(
        world: worldOf(vehicles: [assignedVehicle()]),
        now: t0.add(const Duration(minutes: 10)),
        turboSpeed: 20,
      );
      expect(slow.trips, hasLength(8)); // 600 s / 84 s: departures 0..7
      expect(fast.trips, hasLength(143)); // 600 s / 4.2 s: departures 0..142
    });
  });

  group('safety cap', () {
    final cfg = quietConfig((j) => setDemand(j, 'R01', 1000000));
    final now = t0.add(const Duration(hours: 8));
    final world = worldOf(vehicles: [assignedVehicle()]);

    test('stops a vehicle after the cap in one advance', () {
      final change = simulator(
        cfg: cfg,
        maxSteps: 50,
      ).advance(world: world, now: now, turboSpeed: 20);
      expect(change.trips, hasLength(50));
      expect(change.settledTrips, hasLength(50));
      // Free again at the last arrival, so the next advance carries on.
      expect(
        change.vehicles.single.availableAt,
        t0.add(const Duration(milliseconds: 4200 * 50)),
      );
    });

    test('later advances finish the job: no progress is lost', () {
      final whole = simulator(
        cfg: cfg,
        maxSteps: 100000,
      ).advance(world: world, now: now, turboSpeed: 20);

      final sim = simulator(cfg: cfg, maxSteps: 50);
      var current = world;
      var passes = 0;
      while (true) {
        final change = sim.advance(world: current, now: now, turboSpeed: 20);
        if (change.isEmpty) break;
        current = applyChange(current, change);
        passes++;
        expect(passes, lessThan(1000), reason: 'must terminate');
      }
      expect(current.company.cash, whole.cashAfter);
      expect(current.company.completedTrips, whole.completedTripsAfter);
      expect(passes, greaterThan(100));
    });

    test('the default cap is 1000', () {
      expect(GameSimulator.defaultMaxStepsPerVehicle, 1000);
      final change = simulator(
        cfg: cfg,
      ).advance(world: world, now: now, turboSpeed: 20);
      expect(change.trips, hasLength(1000));
    });

    test('waiting for demand counts toward the cap too', () {
      final starved = quietConfig((j) => setDemand(j, 'R01', 0));
      final change = simulator(
        cfg: starved,
        maxSteps: 5,
      ).advance(world: world, now: now, turboSpeed: 1);
      expect(change.trips, isEmpty);
      // Five waits of one game day each (24 minutes).
      expect(
        change.vehicles.single.availableAt,
        t0.add(const Duration(minutes: 24 * 5)),
      );
    });
  });

  group('other hauls', () {
    test('a Line haul is settled but not sent out again', () {
      final trip = Trip(
        id: 'old',
        vehicleId: 'v1',
        vehicleTier: 6,
        routeId: 'R05',
        cargo: 'General dry',
        loadT: 10,
        departAt: t0,
        arriveAt: t0.add(const Duration(minutes: 9)),
        revenue: 36375,
        costs: const TripCosts(
          energy: 7500,
          toll: 800,
          crew: 1480,
          maintenance: 1000,
          fines: 0,
          accident: 0,
        ),
      );
      final world = worldOf(
        vehicles: [assignedVehicle(tier: 6, routeId: 'R05')],
        unsettledTrips: [trip],
      );
      final change = simulator().advance(
        world: world,
        now: t0.add(const Duration(hours: 2)),
        turboSpeed: 1,
      );
      expect(change.trips, hasLength(1));
      expect(change.trips.single.settled, true);
      expect(change.cashAfter, 1500000 + 36375 - 10780);
      expect(
        change.vehicles.single.availableAt,
        t0.add(const Duration(minutes: 9)),
      );
    });

    test('a vehicle with no assignment is never dispatched', () {
      final change = simulator().advance(
        world: worldOf(
          vehicles: [Vehicle(id: 'v1', tier: 4, purchasedAt: t0)],
        ),
        now: t0.add(const Duration(hours: 1)),
        turboSpeed: 1,
      );
      expect(change.isEmpty, true);
    });

    test('a vehicle that may not run its route is skipped, not retried', () {
      final change = simulator().advance(
        world: worldOf(vehicles: [assignedVehicle(cargo: 'Fuel')]),
        now: t0.add(const Duration(hours: 1)),
        turboSpeed: 1,
      );
      expect(change.isEmpty, true);
    });

    test('a vehicle that is not ready yet waits', () {
      final change = simulator().advance(
        world: worldOf(
          vehicles: [
            assignedVehicle(availableAt: t0.add(const Duration(hours: 2))),
          ],
        ),
        now: t0.add(const Duration(hours: 1)),
        turboSpeed: 1,
      );
      expect(change.isEmpty, true);
    });

    test('a trip of a vehicle that was removed is still paid', () {
      final trip = Trip(
        id: 'orphan',
        vehicleId: 'gone',
        vehicleTier: 4,
        routeId: 'R01',
        cargo: 'General dry',
        loadT: 1.5,
        departAt: t0,
        arriveAt: t0.add(const Duration(seconds: 84)),
        revenue: 2693,
        costs: const TripCosts(
          energy: 338,
          toll: 0,
          crew: 112,
          maintenance: 60,
          fines: 0,
          accident: 0,
        ),
      );
      final change = simulator().advance(
        world: worldOf(unsettledTrips: [trip]),
        now: t0.add(const Duration(minutes: 5)),
        turboSpeed: 1,
      );
      expect(change.cashAfter, 1500000 + profitPerTrip);
      expect(change.vehicles, isEmpty);
    });
  });

  group('fines and accidents with a fixed seed', () {
    // Tier 6 on R05 with a 12 t overload is a Line haul: one trip per advance.
    test('the same seed gives the same cash', () {
      final default_ = loadDefaultConfig();
      ChangeSet run(int seed) {
        final world = worldOf(
          vehicles: [
            assignedVehicle(
              tier: 6,
              routeId: 'R05',
              cargo: 'Rice',
              overloadT: 12,
            ),
          ],
        );
        final sim = simulator(cfg: default_, random: Random(seed));
        final sent = sim.dispatchNow(
          world: world,
          vehicleId: 'v1',
          now: t0,
          turboSpeed: 1,
        );
        final next = applyChange(world, sent.change!);
        return sim.advance(
          world: next,
          now: t0.add(const Duration(hours: 1)),
          turboSpeed: 1,
        );
      }

      expect(run(5).cashAfter, run(5).cashAfter);
      final outcomes = {for (var s = 0; s < 60; s++) run(s).cashAfter};
      // 0, 1 or 2 fines and an accident or not: more than one outcome.
      expect(outcomes.length, greaterThan(1));
      // Revenue is 80,025 and the costs that are not rolled come to 15,280,
      // so no outcome can beat 64,745 profit.
      for (final cash in outcomes) {
        final profit = cash - 1500000;
        expect(profit, lessThanOrEqualTo(80025 - 15280));
      }
    });
  });

  group('dispatchNow', () {
    test('sends an assigned idle vehicle out now', () {
      final world = worldOf(vehicles: [assignedVehicle()]);
      final outcome = simulator().dispatchNow(
        world: world,
        vehicleId: 'v1',
        now: t0.add(const Duration(minutes: 3)),
        turboSpeed: 20,
      );
      expect(outcome.plan, isA<DispatchReady>());
      final change = outcome.change!;
      expect(change.trips.single.departAt, t0.add(const Duration(minutes: 3)));
      expect(
        change.trips.single.arriveAt,
        t0.add(const Duration(minutes: 3, milliseconds: 4200)),
      );
      expect(change.vehicles.single.id, 'v1');
      expect(change.cashAfter, 1500000);
    });

    test('is blocked while the vehicle is on the road', () {
      final sim = simulator();
      final world = worldOf(vehicles: [assignedVehicle()]);
      final first = sim.dispatchNow(
        world: world,
        vehicleId: 'v1',
        now: t0,
        turboSpeed: 1,
      );
      final onRoad = applyChange(world, first.change!);
      final second = sim.dispatchNow(
        world: onRoad,
        vehicleId: 'v1',
        now: t0,
        turboSpeed: 1,
      );
      expect(
        (second.plan as DispatchBlocked).reason,
        DispatchBlockReason.onTheRoad,
      );
      expect(second.change, isNull);
    });

    test('waits when the route has no demand and saves the wait', () {
      final world = worldOf(
        vehicles: [assignedVehicle()],
        routeStates: [
          RouteState(routeId: 'R01', demandRemainingT: 0, updatedAt: t0),
        ],
      );
      final outcome = simulator().dispatchNow(
        world: world,
        vehicleId: 'v1',
        now: t0.add(const Duration(minutes: 1)),
        turboSpeed: 1,
      );
      expect(outcome.plan, isA<DispatchWaiting>());
      expect(
        outcome.change!.vehicles.single.availableAt,
        t0.add(const Duration(minutes: 24)),
      );
      expect(outcome.change!.trips, isEmpty);
    });

    test('rejects without a change when the route is not allowed', () {
      final world = worldOf(
        vehicles: [
          assignedVehicle(tier: 1, routeId: 'R05', cargo: 'Market goods'),
        ],
      );
      final outcome = simulator().dispatchNow(
        world: world,
        vehicleId: 'v1',
        now: t0,
        turboSpeed: 1,
      );
      expect(outcome.plan, isA<DispatchRejected>());
      expect(outcome.change, isNull);
    });

    test('unknown and unassigned vehicles are blocked', () {
      final sim = simulator();
      final world = worldOf(
        vehicles: [Vehicle(id: 'idle', tier: 4, purchasedAt: t0)],
      );
      expect(
        (sim
                    .dispatchNow(
                      world: world,
                      vehicleId: 'nope',
                      now: t0,
                      turboSpeed: 1,
                    )
                    .plan
                as DispatchBlocked)
            .reason,
        DispatchBlockReason.unknownVehicle,
      );
      expect(
        (sim
                    .dispatchNow(
                      world: world,
                      vehicleId: 'idle',
                      now: t0,
                      turboSpeed: 1,
                    )
                    .plan
                as DispatchBlocked)
            .reason,
        DispatchBlockReason.notAssigned,
      );
    });

    test('a Line haul quote matches the economy engine golden trip', () {
      final world = worldOf(
        vehicles: [assignedVehicle(tier: 6, routeId: 'R05')],
      );
      final outcome = simulator(
        cfg: loadDefaultConfig(),
      ).dispatchNow(world: world, vehicleId: 'v1', now: t0, turboSpeed: 1);
      final ready = outcome.plan as DispatchReady;
      expect(ready.trip.revenue, 36375);
      expect(ready.quote.profit, closeTo(23995, 1));
      expect(
        ready.trip.arriveAt,
        t0.add(const Duration(minutes: 9, seconds: 15)),
      );
      expect(TripCosts.fromQuote(ready.quote), ready.trip.costs);
      expect(
        quoteTrip(
          config: loadDefaultConfig(),
          vehicle: loadDefaultConfig().vehicleByTier(6),
          route: loadDefaultConfig().routeById('R05'),
          cargo: loadDefaultConfig().cargoByName('General dry'),
        ).revenueTk,
        ready.trip.revenue,
      );
    });
  });
}
