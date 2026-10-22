import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/sim/game_simulator.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/change_committer.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';

import '../support/sim_support.dart';
import 'save_test_helper.dart';

class SimulatedCrash implements Exception {
  @override
  String toString() => 'SimulatedCrash';
}

/// A committer that "crashes" (throws) right after [step].
ChangeCommitter crashingAfter(SaveDatabase db, CommitStep step) {
  return ChangeCommitter(
    db,
    afterStep: (s) {
      if (s == step) throw SimulatedCrash();
    },
  );
}

const startCash = 1000000;

/// One game situation to settle: how to fill the save and what to simulate.
class Scenario {
  Scenario(this.name, this.config, this.prepare, this.now);

  final String name;
  final EconomyConfig config;

  /// Fills a fresh save before the simulation.
  final Future<void> Function(SaveDatabase db, GameSimulator sim) prepare;
  final DateTime now;
}

GameSimulator simulatorFor(EconomyConfig config, int seed) =>
    GameSimulator(config: config, random: Random(seed), newId: counterIds());

SimWorld loadWorld(SaveDatabase db) => SimWorld(
  company: db.company.load()!,
  vehicles: db.vehicles.all(),
  unsettledTrips: db.trips.unsettled(),
  routeStates: db.routeStates.all(),
  rollupOf: db.dayRollups.forDay,
);

Future<void> seedCompany(SaveDatabase db) {
  return db.company.save(
    Company(name: 'Test Ltd', cash: startCash, createdAt: t0),
  );
}

void main() {
  final folder = SaveFolder()..register();

  // Fines and accidents are certain here, so the rolled costs are large and
  // would show immediately if recovery paid or rolled twice.
  final sure = editedConfig((j) {
    j['settings']['weighbridgeCheckChance'] = 1;
    j['settings']['accidentChancePer100Km'] = 1000;
  });

  final scenarios = [
    Scenario(
      'a Local haul chain: new trips, route demand, vehicle, cash',
      quietConfig(),
      (db, sim) async {
        await seedCompany(db);
        await db.vehicles.put(assignedVehicle());
      },
      t0.add(const Duration(minutes: 10)),
    ),
    Scenario(
      'an overloaded Line haul with fines and an accident',
      sure,
      (db, sim) async {
        await seedCompany(db);
        final vehicle = assignedVehicle(
          tier: 6,
          routeId: 'R05',
          cargo: 'Rice',
          overloadT: 12,
        );
        await db.vehicles.put(vehicle);
        final sent = sim.dispatchNow(
          world: loadWorld(db),
          vehicleId: 'v1',
          now: t0,
          turboSpeed: 1,
        );
        await ChangeCommitter(db).commit(sent.change!);
      },
      t0.add(const Duration(hours: 1)),
    ),
  ];

  for (final scenario in scenarios) {
    group('crash safety: ${scenario.name}', () {
      late SaveDatabase db;
      late ChangeSet change;
      late int expectedCash;
      late SimWorld worldBefore;

      /// A fresh save with the scenario prepared and the change computed.
      Future<void> setUpScenario() async {
        db = await folder.open();
        final sim = simulatorFor(scenario.config, 3);
        await scenario.prepare(db, sim);
        worldBefore = loadWorld(db);
        final before = worldBefore.company.cash;
        change = sim.advance(
          world: worldBefore,
          now: scenario.now,
          turboSpeed: 1,
        );
        expect(change.settledTrips, isNotEmpty);
        // The payout is the sum of the settled trips' profits, once.
        expectedCash =
            before + change.settledTrips.fold<int>(0, (s, t) => s + t.profit);
        expect(change.cashAfter, expectedCash);
      }

      /// The save equals the change, applied exactly once.
      void expectApplied(SaveDatabase check) {
        final company = check.company.load()!;
        expect(company.cash, expectedCash, reason: 'cash is paid once');
        expect(
          company.completedTrips,
          change.completedTripsAfter,
          reason: 'trip count is counted once',
        );
        final settled = change.settledTrips;
        expect(
          company.lifetimeRevenue,
          settled.fold<int>(0, (s, t) => s + t.revenue),
          reason: 'lifetime revenue is counted once',
        );
        expect(
          company.lifetimeCosts,
          settled.fold(TripCosts.zero, (s, t) => s + t.costs),
          reason: 'lifetime costs are counted once',
        );
        final days = check.dayRollups.all();
        expect(days, unorderedEquals(change.dayRollups));
        expect(
          days.fold<int>(0, (s, d) => s + d.trips),
          settled.length,
          reason: 'each settled trip is in exactly one day',
        );
        for (final trip in change.trips) {
          expect(check.trips.get(trip.id), trip, reason: 'trip ${trip.id}');
        }
        for (final vehicle in change.vehicles) {
          expect(check.vehicles.get(vehicle.id), vehicle);
        }
        for (final route in change.routeStates) {
          expect(check.routeStates.get(route.routeId), route);
        }
        expect(check.pending.load(), isNull);
        expect(check.trips.unsettled().every((t) => !t.settled), true);
        expect(
          check.trips.all().where((t) => t.settled).length,
          change.settledTrips.length,
        );
      }

      test('a clean commit applies the change once', () async {
        await setUpScenario();
        await ChangeCommitter(db).commit(change);
        expectApplied(db);
      });

      for (final step in CommitStep.values) {
        test('a crash after ${step.name}, then restart', () async {
          await setUpScenario();

          await expectLater(
            crashingAfter(db, step).commit(change),
            throwsA(isA<SimulatedCrash>()),
          );
          // The process dies; the save is reopened from disk.
          await db.close();
          final reopened = await folder.open();

          final recovered = await ChangeCommitter(reopened).recoverPending();
          expect(
            recovered,
            step != CommitStep.pendingCleared,
            reason: 'there is something to finish unless the commit completed',
          );
          expectApplied(reopened);

          // Starting again and again changes nothing more.
          expect(await ChangeCommitter(reopened).recoverPending(), false);
          expectApplied(reopened);
        });

        test(
          'a crash after ${step.name}, then another during recovery',
          () async {
            await setUpScenario();
            await expectLater(
              crashingAfter(db, step).commit(change),
              throwsA(isA<SimulatedCrash>()),
            );
            await db.close();
            var reopened = await folder.open();

            // Recovery itself crashes after its first apply step, if there is
            // anything left to apply.
            try {
              await crashingAfter(
                reopened,
                CommitStep.companySaved,
              ).recoverPending();
            } on SimulatedCrash {
              // expected unless nothing was pending
            }
            await reopened.close();
            reopened = await folder.open();

            await ChangeCommitter(reopened).recoverPending();
            expectApplied(reopened);
          },
        );
      }

      test('a crash before anything is written loses nothing', () async {
        await setUpScenario();
        // The simulation ran but the commit never started. Nothing on disk.
        await db.close();
        final reopened = await folder.open();
        expect(await ChangeCommitter(reopened).recoverPending(), false);
        expect(reopened.company.load()!.cash, startCash);

        // The trips are still unsettled, so the next run pays them once.
        final again = simulatorFor(
          scenario.config,
          3,
        ).advance(world: loadWorld(reopened), now: scenario.now, turboSpeed: 1);
        expect(again.cashAfter, expectedCash);
        await ChangeCommitter(reopened).commit(again);
        expect(reopened.company.load()!.cash, expectedCash);
      });

      test('the next commit finishes an interrupted one first', () async {
        await setUpScenario();
        await expectLater(
          crashingAfter(db, CommitStep.vehiclesSaved).commit(change),
          throwsA(isA<SimulatedCrash>()),
        );

        // Same process, no restart: a later change builds on the first.
        final world = applyChange(worldBefore, change);
        final later = simulatorFor(scenario.config, 4).advance(
          world: world,
          now: scenario.now.add(const Duration(minutes: 30)),
          turboSpeed: 1,
        );
        await ChangeCommitter(db).commit(later);

        expect(db.pending.load(), isNull);
        expect(db.company.load()!.cash, later.cashAfter);
        // Everything from the first change is on disk too.
        for (final trip in change.settledTrips) {
          expect(db.trips.get(trip.id)!.settled, true);
        }
      });
    });
  }

  test(
    'the pending record holds the rolled costs, so recovery never rerolls',
    () async {
      final db = await folder.open();
      final scenario = scenarios[1];
      final sim = simulatorFor(scenario.config, 3);
      await scenario.prepare(db, sim);
      final change = sim.advance(
        world: loadWorld(db),
        now: scenario.now,
        turboSpeed: 1,
      );
      final settled = change.settledTrips.single;
      // Two weighbridges at 29,000 and a 320,000 accident were rolled.
      expect(settled.costs.fines, 58000);
      expect(settled.costs.accident, 320000);

      await expectLater(
        crashingAfter(db, CommitStep.pendingWritten).commit(change),
        throwsA(isA<SimulatedCrash>()),
      );
      await db.close();
      final reopened = await folder.open();

      // Even with a recovery that would roll differently, the stored costs win.
      await ChangeCommitter(reopened).recoverPending();
      final recovered = reopened.trips.get(settled.id)!;
      expect(recovered.costs.fines, 58000);
      expect(recovered.costs.accident, 320000);
      expect(recovered.settled, true);
    },
  );

  test('recover does nothing on a save with no pending record', () async {
    final db = await folder.open();
    await seedCompany(db);
    expect(await ChangeCommitter(db).recoverPending(), false);
    expect(db.company.load()!.cash, startCash);
  });

  group('crash safety: a purchase, a sale, a permit and pruning', () {
    late SaveDatabase db;
    final bought = Vehicle(id: 'v9', tier: 5, purchasedAt: t0);
    final oldTrip = Trip(
      id: 'trip_old',
      vehicleId: 'v1',
      vehicleTier: 4,
      routeId: 'R01',
      cargo: 'General dry',
      loadT: 1.5,
      departAt: t0,
      arriveAt: t0.add(const Duration(seconds: 84)),
      revenue: 2693,
      costs: TripCosts.zero,
      settled: true,
    );
    final change = ChangeSet(
      cashAfter: startCash - 400000,
      completedTripsAfter: 0,
      vehicles: [bought],
      removedVehicleIds: ['v1'],
      removedTripIds: ['trip_old'],
      permitsAfter: {'light'},
    );

    Future<void> setUp() async {
      db = await folder.open();
      await seedCompany(db);
      await db.vehicles.put(assignedVehicle());
      await db.trips.put(oldTrip);
    }

    void expectApplied(SaveDatabase check) {
      final company = check.company.load()!;
      expect(company.cash, startCash - 400000, reason: 'paid once');
      expect(company.permits, {'light'});
      expect(check.vehicles.get('v9'), bought);
      expect(check.vehicles.get('v1'), isNull, reason: 'the sold one is gone');
      expect(check.vehicles.count, 1);
      expect(check.trips.get('trip_old'), isNull, reason: 'pruned');
      expect(check.pending.load(), isNull);
    }

    test('a clean commit', () async {
      await setUp();
      await ChangeCommitter(db).commit(change);
      expectApplied(db);
    });

    for (final step in CommitStep.values) {
      test('a crash after ${step.name}, then restart', () async {
        await setUp();
        await expectLater(
          crashingAfter(db, step).commit(change),
          throwsA(isA<SimulatedCrash>()),
        );
        await db.close();
        final reopened = await folder.open();
        await ChangeCommitter(reopened).recoverPending();
        expectApplied(reopened);
        expect(await ChangeCommitter(reopened).recoverPending(), false);
        expectApplied(reopened);
      });
    }
  });

  test('settling adds to a day rollup that is already saved', () async {
    final db = await folder.open();
    await seedCompany(db);
    await db.vehicles.put(assignedVehicle());
    final sim = simulatorFor(quietConfig(), 1);

    // Two commits on the same game day: the second builds on the first.
    final first = sim.advance(
      world: loadWorld(db),
      now: t0.add(const Duration(minutes: 3)),
      turboSpeed: 1,
    );
    await ChangeCommitter(db).commit(first);
    final second = sim.advance(
      world: loadWorld(db),
      now: t0.add(const Duration(minutes: 6)),
      turboSpeed: 1,
    );
    await ChangeCommitter(db).commit(second);

    final day = db.dayRollups.forDay(0)!;
    final settled = db.trips.all().where((t) => t.settled).toList();
    expect(
      settled,
      hasLength(first.settledTrips.length + second.settledTrips.length),
    );
    expect(day.trips, settled.length);
    expect(day.revenue, settled.fold<int>(0, (s, t) => s + t.revenue));
    expect(db.company.load()!.lifetimeRevenue, day.revenue);
  });

  test('committing a change keeps the permits the company owns', () async {
    final db = await folder.open();
    await db.company.save(
      Company(
        name: 'Test Ltd',
        cash: startCash,
        createdAt: t0,
        permits: {'light', 'hazmat'},
      ),
    );
    await ChangeCommitter(
      db,
    ).commit(ChangeSet(cashAfter: startCash + 500, completedTripsAfter: 2));
    final company = db.company.load()!;
    expect(company.cash, startCash + 500);
    expect(company.completedTrips, 2);
    expect(company.permits, {'light', 'hazmat'});
  });

  test('a change set round-trips through the pending record on disk', () async {
    var db = await folder.open();
    await seedCompany(db);
    await db.vehicles.put(assignedVehicle());
    final sim = simulatorFor(quietConfig(), 1);
    final change = sim.advance(
      world: loadWorld(db),
      now: t0.add(const Duration(minutes: 3)),
      turboSpeed: 1,
    );
    await db.pending.save(change);
    await db.close();

    db = await folder.open();
    final loaded = db.pending.load()!;
    expect(loaded.cashAfter, change.cashAfter);
    expect(loaded.completedTripsAfter, change.completedTripsAfter);
    expect(loaded.trips, change.trips);
    expect(loaded.vehicles, change.vehicles);
    expect(loaded.routeStates, change.routeStates);
  });
}
