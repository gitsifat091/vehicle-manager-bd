import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/core/sim/dispatch.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';
import 'package:vehicle_manager_bd/state/game_engine.dart';

import '../data/save_test_helper.dart';
import '../support/sim_support.dart';

void main() {
  final folder = SaveFolder()..register();

  // Accidents off, so a Tier 4 trip on R01 always earns exactly 2183 Taka.
  const profitPerTrip = 2183;
  late ManualClock clock;
  late SaveDatabase db;
  late String Function(String) ids;
  late GameEngine engine;

  GameEngine makeEngine({EconomyConfig? config, int seed = 1}) {
    return GameEngine(
      config: config ?? quietConfig(),
      database: db,
      clock: clock,
      random: Random(seed),
      newId: ids,
    );
  }

  setUp(() async {
    clock = ManualClock();
    ids = counterIds();
    db = await folder.open();
    engine = makeEngine();
  });

  tearDown(() => engine.dispose());

  Vehicle idleVehicle(String id, int tier) =>
      Vehicle(id: id, tier: tier, purchasedAt: t0);

  /// Lets the Turbo Start run out, so trips take their normal time.
  Future<void> finishTurbo() async {
    clock.advance(const Duration(minutes: 61));
    await engine.tick();
    expect(engine.turboSpeed, 1);
  }

  Duration tripTime(Trip t) => t.arriveAt.difference(t.departAt);

  group('new game', () {
    test(
      'starts with the starting cash and full demand on every route',
      () async {
        await engine.startNewGame('Sifat Ltd');
        final company = db.company.load()!;
        expect(company.name, 'Sifat Ltd');
        expect(company.cash, 1500000);
        expect(company.createdAt, t0);
        expect(company.turboElapsed, Duration.zero);
        expect(db.routeStates.count, 16);
        expect(db.routeStates.get('R05')!.demandRemainingT, 400);
        expect(db.routeStates.get('R05')!.gameDay, 0);
        expect(engine.turboSpeed, 20);
      },
    );

    test('erases an older save', () async {
      await engine.startNewGame('Old');
      await db.vehicles.put(idleVehicle('v1', 4));
      await engine.startNewGame('New');
      expect(db.vehicles.count, 0);
      expect(db.company.load()!.name, 'New');
    });

    test('start and tick do nothing without a company', () async {
      await engine.start();
      await engine.tick();
      expect(db.company.exists, false);
      expect(engine.turboSpeed, 1);
    });
  });

  group('turbo start', () {
    setUp(() async {
      await engine.startNewGame('Test Ltd');
      await db.vehicles.putAll([
        idleVehicle('a', 4),
        idleVehicle('b', 4),
        idleVehicle('c', 4),
        idleVehicle('d', 4),
      ]);
    });

    Future<Trip> assignAndGetTrip(String vehicleId) async {
      final outcome = await engine.assignVehicle(
        vehicleId,
        routeId: 'R01',
        cargoName: 'General dry',
      );
      return (outcome.plan as DispatchReady).trip;
    }

    test('dispatch speed follows the foreground phases', () async {
      // Tier 4 on R01 is 1.4 game hours: 84 s at 1x.
      expect(
        tripTime(await assignAndGetTrip('a')),
        const Duration(milliseconds: 4200),
      );

      clock.advance(const Duration(minutes: 20));
      expect(engine.turboSpeed, 10);
      expect(
        tripTime(await assignAndGetTrip('b')),
        const Duration(milliseconds: 8400),
      );

      clock.advance(const Duration(minutes: 20));
      expect(engine.turboSpeed, 5);
      expect(
        tripTime(await assignAndGetTrip('c')),
        const Duration(milliseconds: 16800),
      );

      clock.advance(const Duration(minutes: 20));
      expect(engine.turboSpeed, 1);
      expect(
        tripTime(await assignAndGetTrip('d')),
        const Duration(seconds: 84),
      );
    });

    test('is frozen while the app is in the background', () async {
      clock.advance(const Duration(minutes: 5));
      await engine.pause();
      expect(db.company.load()!.turboElapsed, const Duration(minutes: 5));

      clock.advance(const Duration(hours: 3));
      expect(engine.turboElapsed, const Duration(minutes: 5));
      expect(engine.turboSpeed, 20);

      await engine.resume();
      clock.advance(const Duration(minutes: 15));
      expect(engine.turboElapsed, const Duration(minutes: 20));
      expect(engine.turboSpeed, 10);
    });

    test(
      'survives a restart: the saved foreground time is picked up',
      () async {
        clock.advance(const Duration(minutes: 5));
        await engine.pause();
        await db.close();

        // Hours pass with the app closed, then it opens again.
        clock.advance(const Duration(hours: 6));
        db = await folder.open();
        final restarted = makeEngine();
        await restarted.start();
        expect(restarted.turboElapsed, const Duration(minutes: 5));
        expect(restarted.turboSpeed, 20);

        clock.advance(const Duration(minutes: 15));
        expect(restarted.turboSpeed, 10);
        restarted.dispose();
      },
    );

    test(
      'the elapsed time is saved on each tick while the turbo runs',
      () async {
        clock.advance(const Duration(minutes: 2));
        await engine.tick();
        expect(db.company.load()!.turboElapsed, const Duration(minutes: 2));
      },
    );

    test('the saved value stops at the end of the turbo', () async {
      clock.advance(const Duration(hours: 3));
      await engine.tick();
      expect(db.company.load()!.turboElapsed, const Duration(minutes: 60));
    });

    test('the game clock bonus follows the foreground phases', () async {
      expect(engine.turboBonus, Duration.zero);
      clock.advance(const Duration(minutes: 1));
      expect(engine.turboBonus, const Duration(minutes: 19));
      clock.advance(const Duration(minutes: 19));
      expect(engine.turboBonus, const Duration(minutes: 380));
      clock.advance(const Duration(minutes: 40));
      expect(engine.turboBonus, const Duration(minutes: 640));
      clock.advance(const Duration(hours: 5));
      expect(engine.turboBonus, const Duration(minutes: 640));
    });

    test('the bonus does not grow in the background', () async {
      clock.advance(const Duration(minutes: 5));
      await engine.pause();
      clock.advance(const Duration(hours: 3));
      expect(engine.turboBonus, const Duration(minutes: 95));
    });
  });

  group('first hour', () {
    // Tier 4 on R01 has 60 t of demand a day and takes 1.5 t a trip: 40 trips
    // use the whole day. Before the game clock followed the turbo, a day was
    // 24 real minutes even at 20x, so the pickup used up the demand within
    // about 3 minutes and then stood still for most of the turbo window.
    test('a pickup on R01 keeps working through the turbo window', () async {
      await engine.startNewGame('Test Ltd');
      await db.vehicles.put(idleVehicle('v1', 4));
      await engine.assignVehicle(
        'v1',
        routeId: 'R01',
        cargoName: 'General dry',
      );

      var waitedOnDemand = Duration.zero;
      var lastSeen = Duration.zero;
      // The player keeps the app open for the whole hour; the timer ticks.
      for (var second = 10; second <= 3600; second += 10) {
        clock.advance(const Duration(seconds: 10));
        await engine.tick();
        lastSeen = Duration(seconds: second);
      }
      expect(lastSeen, const Duration(minutes: 60));
      expect(engine.turboSpeed, 1);

      final trips = db.trips.all()
        ..sort((a, b) => a.departAt.compareTo(b.departAt));
      for (var i = 1; i < trips.length; i++) {
        waitedOnDemand += trips[i].departAt.difference(trips[i - 1].arriveAt);
      }

      // 20 min at 4.2 s a trip, 20 min at 8.4 s, 20 min at 16.8 s: about 500.
      final completed = db.company.load()!.completedTrips;
      expect(completed, greaterThan(480));
      // The vehicle never waits for the next day: it is always on the road,
      // apart from the rounding of the 10 second ticks.
      expect(waitedOnDemand, lessThan(const Duration(seconds: 1)));
      // 60 real minutes of foreground play are 700 game clock minutes.
      expect(db.routeStates.get('R01')!.gameDay, 29);
    });

    test('demand still limits a fleet that outruns the game day', () async {
      // At 20x a game day is 72 real seconds and offers 0.83 t/s on R01. One
      // pickup needs 0.36 t/s, but four together need 1.43 t/s and run dry.
      await engine.startNewGame('Test Ltd');
      await db.vehicles.putAll([
        for (var i = 0; i < 4; i++) idleVehicle('v$i', 4),
      ]);
      for (var i = 0; i < 4; i++) {
        await engine.assignVehicle(
          'v$i',
          routeId: 'R01',
          cargoName: 'General dry',
        );
      }
      for (var i = 0; i < 12; i++) {
        clock.advance(const Duration(seconds: 10));
        await engine.tick();
      }
      final trips = db.trips.all();
      final carried = trips.fold<double>(0, (sum, t) => sum + t.loadT);
      // 2 minutes at 20x is 40 game clock minutes: days 0 and 1, so at most
      // 120 t, and the fleet used nearly all of it.
      expect(carried, lessThanOrEqualTo(120 + 1e-6));
      expect(carried, greaterThan(100));
    });
  });

  group('dispatch', () {
    setUp(() async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
    });

    test(
      'assigning a route sends the vehicle out now and consumes demand',
      () async {
        await db.vehicles.put(idleVehicle('v1', 4));
        final sentAt = clock.now();
        final outcome = await engine.assignVehicle(
          'v1',
          routeId: 'R01',
          cargoName: 'General dry',
        );
        final ready = outcome.plan as DispatchReady;

        final trip = db.trips.get(ready.trip.id)!;
        expect(trip.departAt, sentAt);
        expect(trip.arriveAt, sentAt.add(const Duration(seconds: 84)));
        expect(trip.settled, false);
        final vehicle = db.vehicles.get('v1')!;
        expect(vehicle.assignedRouteId, 'R01');
        expect(vehicle.assignedCargo, 'General dry');
        expect(vehicle.availableAt, sentAt);
        expect(
          db.routeStates.get('R01')!.demandRemainingT,
          closeTo(58.5, 1e-9),
        );
      },
    );

    test('a rejected assignment leaves the vehicle untouched', () async {
      await db.vehicles.put(idleVehicle('v1', 1));
      final outcome = await engine.assignVehicle(
        'v1',
        routeId: 'R05',
        cargoName: 'Market goods',
      );
      expect(outcome.plan, isA<DispatchRejected>());
      expect(db.vehicles.get('v1')!.isAssigned, false);
      expect(db.trips.count, 0);
    });

    test('a vehicle on the road cannot be assigned again', () async {
      await db.vehicles.put(idleVehicle('v1', 4));
      await engine.assignVehicle(
        'v1',
        routeId: 'R01',
        cargoName: 'General dry',
      );
      final second = await engine.assignVehicle(
        'v1',
        routeId: 'R02',
        cargoName: 'General dry',
      );
      expect(
        (second.plan as DispatchBlocked).reason,
        DispatchBlockReason.onTheRoad,
      );
      expect(db.vehicles.get('v1')!.assignedRouteId, 'R01');
      expect(db.trips.count, 1);
    });

    test('an unknown vehicle is blocked', () async {
      final outcome = await engine.assignVehicle(
        'ghost',
        routeId: 'R01',
        cargoName: 'General dry',
      );
      expect(
        (outcome.plan as DispatchBlocked).reason,
        DispatchBlockReason.unknownVehicle,
      );
    });

    test(
      'with no demand left the vehicle waits for the next game day',
      () async {
        await db.vehicles.put(idleVehicle('v1', 4));
        await db.routeStates.put(
          RouteState(
            routeId: 'R01',
            demandRemainingT: 0,
            updatedAt: clock.now(),
          ),
        );
        final outcome = await engine.assignVehicle(
          'v1',
          routeId: 'R01',
          cargoName: 'General dry',
        );
        expect(outcome.plan, isA<DispatchWaiting>());
        expect(db.trips.count, 0);

        // The game clock is real time plus the turbo bonus (640 minutes once
        // the turbo is over). Days are 24 game clock minutes from creation.
        final until = (outcome.plan as DispatchWaiting).until;
        expect(db.vehicles.get('v1')!.availableAt, until);
        expect(engine.turboBonus, const Duration(minutes: 640));
        expect((until.difference(t0) + engine.turboBonus).inMinutes % 24, 0);
        expect(until.isAfter(clock.now()), true);

        // When the day starts, the next tick sends it out by itself.
        clock.advance(
          until.difference(clock.now()) + const Duration(seconds: 1),
        );
        await engine.tick();
        expect(db.trips.count, 1);
        expect(db.trips.all().single.departAt, until);
      },
    );

    test(
      'a Line haul is paid on arrival and then waits for the player',
      () async {
        await db.vehicles.put(idleVehicle('v1', 6));
        final start = db.company.load()!.cash;
        await engine.assignVehicle(
          'v1',
          routeId: 'R05',
          cargoName: 'General dry',
        );

        clock.advance(const Duration(minutes: 5));
        await engine.tick();
        expect(db.company.load()!.cash, start, reason: 'not arrived yet');

        clock.advance(const Duration(minutes: 5));
        await engine.tick();
        // Revenue 36,375 less energy 7,500, toll 800, crew 1,480, maintenance 1,000.
        expect(db.company.load()!.cash, start + 36375 - 10780);
        expect(db.company.load()!.completedTrips, 1);
        expect(db.trips.unsettled(), isEmpty);

        final again = await engine.dispatchVehicle('v1');
        expect(again.plan, isA<DispatchReady>());
        expect(db.trips.unsettled(), hasLength(1));
      },
    );
  });

  group('settling', () {
    setUp(() async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
      await db.vehicles.put(idleVehicle('v1', 4));
      await engine.assignVehicle(
        'v1',
        routeId: 'R01',
        cargoName: 'General dry',
      );
    });

    test(
      'a tick settles what arrived and sends the Local haul out again',
      () async {
        final start = db.company.load()!.cash;
        clock.advance(const Duration(seconds: 100));
        await engine.tick();

        expect(db.company.load()!.cash, start + profitPerTrip);
        expect(db.company.load()!.completedTrips, 1);
        final trips = db.trips.all()
          ..sort((a, b) => a.departAt.compareTo(b.departAt));
        expect(trips, hasLength(2));
        expect(trips[0].settled, true);
        expect(trips[1].settled, false);
        expect(trips[1].departAt, trips[0].arriveAt, reason: 'back to back');
      },
    );

    test('a second tick with no time passing changes nothing', () async {
      clock.advance(const Duration(seconds: 100));
      await engine.tick();
      final cash = db.company.load()!.cash;
      final trips = db.trips.count;
      await engine.tick();
      await engine.tick();
      expect(db.company.load()!.cash, cash);
      expect(db.trips.count, trips);
    });

    test('ticks that overlap never pay a trip twice', () async {
      final start = db.company.load()!.cash;
      clock.advance(const Duration(seconds: 100));
      await Future.wait([for (var i = 0; i < 8; i++) engine.tick()]);
      expect(db.company.load()!.cash, start + profitPerTrip);
      expect(db.company.load()!.completedTrips, 1);
    });

    test('listeners hear about a change but not about an empty tick', () async {
      var heard = 0;
      engine.addListener(() => heard++);
      await engine.tick();
      expect(heard, 0);
      clock.advance(const Duration(seconds: 100));
      await engine.tick();
      expect(heard, 1);
    });
  });

  group('8 hours away', () {
    test(
      'catches up on a restart: 342 trips paid, one still on the road',
      () async {
        await engine.startNewGame('Test Ltd');
        await finishTurbo();
        await db.vehicles.put(idleVehicle('v1', 4));
        await engine.assignVehicle(
          'v1',
          routeId: 'R01',
          cargoName: 'General dry',
        );
        final start = db.company.load()!.cash;
        await engine.pause();
        await db.close();

        // The app is closed for 8 hours.
        clock.advance(const Duration(hours: 8));
        db = await folder.open();
        final restarted = makeEngine(seed: 2);
        await restarted.start();

        final company = db.company.load()!;
        expect(company.cash, start + 342 * profitPerTrip);
        expect(company.completedTrips, 342);
        expect(db.trips.count, 343);
        expect(db.trips.unsettled(), hasLength(1));
        restarted.dispose();
      },
    );

    test('the time away does not use up the Turbo Start', () async {
      await engine.startNewGame('Test Ltd');
      await db.vehicles.put(idleVehicle('v1', 4));
      await engine.assignVehicle(
        'v1',
        routeId: 'R01',
        cargoName: 'General dry',
      );
      clock.advance(const Duration(minutes: 3));
      await engine.pause();
      await db.close();

      clock.advance(const Duration(hours: 8));
      db = await folder.open();
      final restarted = makeEngine();
      await restarted.start();

      expect(restarted.turboElapsed, const Duration(minutes: 3));
      expect(restarted.turboSpeed, 20);
      // Trips dispatched during the catch-up run at the frozen turbo speed.
      final newest = db.trips.all()
        ..sort((a, b) => b.departAt.compareTo(a.departAt));
      expect(tripTime(newest.first), const Duration(milliseconds: 4200));
      restarted.dispose();
    });
  });

  group('crash recovery on start', () {
    test('finishes a change that was written but not applied', () async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
      final cash = db.company.load()!.cash;

      // A crash right after the pending record was written.
      await db.pending.save(
        ChangeSet(
          cashAfter: cash + 5000,
          completedTripsAfter: 3,
          trips: [
            Trip(
              id: 'trip_x',
              vehicleId: 'v1',
              vehicleTier: 4,
              routeId: 'R01',
              cargo: 'General dry',
              loadT: 1.5,
              departAt: t0,
              arriveAt: t0.add(const Duration(seconds: 84)),
              revenue: 5000,
              costs: const TripCosts(
                energy: 0,
                toll: 0,
                crew: 0,
                maintenance: 0,
                fines: 0,
                accident: 0,
              ),
              settled: true,
            ),
          ],
        ),
      );
      await db.close();
      db = await folder.open();

      final restarted = makeEngine();
      await restarted.start();
      expect(db.company.load()!.cash, cash + 5000);
      expect(db.trips.get('trip_x')!.settled, true);
      expect(db.pending.load(), isNull);

      // Starting again does not pay it again.
      await restarted.start();
      expect(db.company.load()!.cash, cash + 5000);
      restarted.dispose();
    });
  });

  test('the sim quotes match the economy engine', () async {
    await engine.startNewGame('Test Ltd');
    await finishTurbo();
    await db.vehicles.put(idleVehicle('v1', 6));
    final outcome = await engine.assignVehicle(
      'v1',
      routeId: 'R05',
      cargoName: 'General dry',
    );
    final trip = (outcome.plan as DispatchReady).trip;
    final cfg = quietConfig();
    final quote = quoteTrip(
      config: cfg,
      vehicle: cfg.vehicleByTier(6),
      route: cfg.routeById('R05'),
      cargo: cfg.cargoByName('General dry'),
    );
    expect(trip.revenue, quote.revenueTk);
    expect(trip.revenue, 36375);
    expect(tripTime(trip), const Duration(minutes: 9, seconds: 15));
  });
}
