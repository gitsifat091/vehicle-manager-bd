import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/purchase_rules.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/core/economy/unlock_rules.dart';
import 'package:vehicle_manager_bd/core/sim/dispatch.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/change_committer.dart';
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

  GameEngine makeEngine({
    EconomyConfig? config,
    int seed = 1,
    ChangeCommitter? committer,
  }) {
    return GameEngine(
      config: config ?? quietConfig(),
      database: db,
      clock: clock,
      random: Random(seed),
      newId: ids,
      committer: committer,
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
      expect(db.vehicles.get('v1'), isNull, reason: 'the old vehicle is gone');
      expect(db.vehicles.count, 1, reason: 'only the new free starter');
      expect(db.company.load()!.name, 'New');
    });

    test('grants the free starter vehicle, not yet assigned', () async {
      await engine.startNewGame('Sifat Ltd');
      final vehicles = db.vehicles.all();
      expect(vehicles, hasLength(1));
      final starter = vehicles.single;
      expect(starter.tier, 4);
      expect(starter.id, startsWith('veh_'));
      expect(starter.purchasedAt, t0);
      expect(starter.isAssigned, false);
      expect(starter.availableAt, isNull);
      expect(engine.snapshot.freeGarageSlots, 5);
    });

    test('the starter tier comes from the settings', () async {
      final custom = GameEngine(
        config: editedConfig((j) => j['settings']['starterVehicleTier'] = 2),
        database: db,
        clock: clock,
        newId: ids,
      );
      addTearDown(custom.dispose);
      await custom.startNewGame('A');
      expect(db.vehicles.all().single.tier, 2);
    });

    test('starting again gives one starter, not two', () async {
      await engine.startNewGame('First');
      await engine.startNewGame('Second');
      expect(db.vehicles.count, 1);
    });

    test('the company is written last', () async {
      // Every other record is useless without the company, so a game that
      // dies half way must look like no game at all. The starter and the
      // route states are already there by the time the company is saved.
      final order = <String>[];
      db.vehicles.box.watch().listen((_) => order.add('vehicle'));
      db.routeStates.box.watch().listen((_) => order.add('routes'));
      db.company.box.watch().listen((_) => order.add('company'));
      await engine.startNewGame('A');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(order.last, 'company');
      expect(order.where((e) => e == 'company'), hasLength(1));
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

    test('lifetime totals and the day rollup count every paid trip', () async {
      // 10 minutes: seven 84 s trips arrive.
      clock.advance(const Duration(minutes: 10));
      await engine.tick();
      final company = db.company.load()!;
      expect(company.completedTrips, 7);
      expect(company.lifetimeProfit, 7 * profitPerTrip);
      expect(company.lifetimeRevenue, 7 * 2693);

      final days = db.dayRollups.all();
      expect(days.fold<int>(0, (s, d) => s + d.trips), 7);
      expect(days.fold<int>(0, (s, d) => s + d.profit), 7 * profitPerTrip);
      expect(
        days.fold<int>(0, (s, d) => s + d.revenue),
        company.lifetimeRevenue,
      );
    });
  });

  group('buying', () {
    // Enough cash that only the rule under test can refuse.
    GameEngine richEngine() => makeEngine(
      config: quietConfig((j) => j['settings']['startingCash'] = 100000000),
    );

    test('a vehicle: cash down by its price, idle in the garage', () async {
      await engine.startNewGame('Test Ltd');
      var heard = 0;
      engine.addListener(() => heard++);

      final outcome = await engine.buyVehicle(2);

      expect(outcome.bought, true);
      expect(outcome.rejection, isNull);
      final vehicle = outcome.vehicle!;
      expect(vehicle.tier, 2);
      expect(vehicle.isAssigned, false);
      expect(vehicle.purchasedAt, clock.now());
      expect(db.vehicles.get(vehicle.id), vehicle);
      expect(db.vehicles.count, 2, reason: 'the starter and the new one');
      expect(db.company.load()!.cash, 1500000 - 150000);
      expect(db.pending.load(), isNull);
      expect(heard, 1);
      expect(engine.snapshot.vehicles, hasLength(2));
    });

    test('the new vehicle can be sent to work', () async {
      await engine.startNewGame('Test Ltd');
      final vehicle = (await engine.buyVehicle(4)).vehicle!;
      final outcome = await engine.assignVehicle(
        vehicle.id,
        routeId: 'R02',
        cargoName: 'General dry',
      );
      expect(outcome.plan, isA<DispatchReady>());
    });

    test('a locked vehicle is refused and nothing is saved', () async {
      await engine.startNewGame('Test Ltd');
      var heard = 0;
      engine.addListener(() => heard++);

      final outcome = await engine.buyVehicle(3);

      expect(outcome.bought, false);
      expect(outcome.rejection!.reason, PurchaseRejectionReason.locked);
      expect(outcome.rejection!.unlock!.deliveriesNeeded, 5);
      expect(db.vehicles.count, 1);
      expect(db.company.load()!.cash, 1500000);
      expect(heard, 0);
    });

    test('a full garage is refused', () async {
      await engine.startNewGame('Test Ltd');
      for (var i = 0; i < 5; i++) {
        expect((await engine.buyVehicle(1)).bought, true, reason: 'van $i');
      }
      final outcome = await engine.buyVehicle(1);
      expect(
        outcome.rejection!.reason,
        PurchaseRejectionReason.noFreeGarageSlot,
      );
      expect(db.vehicles.count, 6);
      expect(db.company.load()!.cash, 1500000 - 5 * 20000);
    });

    test('a vehicle the cash does not cover is refused', () async {
      await engine.startNewGame('Test Ltd');
      expect((await engine.buyVehicle(4)).bought, true);
      // Tk 2 lakh left, a Sathi Plus costs Tk 13 lakh.
      final outcome = await engine.buyVehicle(4);
      expect(outcome.rejection!.reason, PurchaseRejectionReason.notEnoughCash);
      expect(db.company.load()!.cash, 200000);
      expect(db.vehicles.count, 2);
    });

    test('a permit: cash down once, and its vehicles unlock', () async {
      engine.dispose();
      engine = richEngine();
      await engine.startNewGame('Test Ltd');
      expect(
        (await engine.buyVehicle(5)).rejection!.reason,
        PurchaseRejectionReason.locked,
      );
      var heard = 0;
      engine.addListener(() => heard++);

      expect(await engine.buyPermit('light'), isNull);

      final company = db.company.load()!;
      expect(company.permits, {'light'});
      expect(company.cash, 100000000 - 400000);
      expect(db.pending.load(), isNull);
      expect(heard, 1);
      expect(engine.snapshot.permits, {'light'});
      expect((await engine.buyVehicle(5)).bought, true);
      expect(db.company.load()!.cash, 100000000 - 400000 - 2500000);
    });

    test('a permit is bought only once', () async {
      engine.dispose();
      engine = richEngine();
      await engine.startNewGame('Test Ltd');
      await engine.buyPermit('medium');
      final again = await engine.buyPermit('medium');
      expect(again!.reason, PermitRejectionReason.alreadyOwned);
      expect(db.company.load()!.cash, 100000000 - 500000);
    });

    test('a permit the cash does not cover is refused', () async {
      engine.dispose();
      engine = makeEngine(
        config: quietConfig((j) => j['settings']['startingCash'] = 399999),
      );
      await engine.startNewGame('Test Ltd');
      final refused = await engine.buyPermit('light');
      expect(refused!.reason, PermitRejectionReason.notEnoughCash);
      expect(db.company.load()!.permits, isEmpty);
      expect(db.company.load()!.cash, 399999);
    });

    test('buying a permit keeps the cash a settled trip just paid', () async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
      final starter = db.vehicles.all().single;
      await engine.assignVehicle(
        starter.id,
        routeId: 'R01',
        cargoName: 'General dry',
      );
      clock.advance(const Duration(seconds: 100));
      await engine.tick();
      final cash = db.company.load()!.cash;
      expect(cash, 1500000 + profitPerTrip);

      expect(await engine.buyPermit('light'), isNull);
      final company = db.company.load()!;
      expect(company.cash, cash - 400000);
      expect(company.completedTrips, 1, reason: 'unchanged by the purchase');
      expect(company.lifetimeRevenue, 2693, reason: 'unchanged too');
    });

    test('without a game a purchase is a programming error', () async {
      expect(() => engine.buyVehicle(4), throwsStateError);
      expect(() => engine.buyPermit('light'), throwsStateError);
    });
  });

  group('selling', () {
    // The free starter sells for settings.starterSaleValue, not 60 percent.
    const starterSale = 150000;

    String starterId() => db.vehicles.all().single.id;

    test('the idle starter sells for the fixed starter value', () async {
      await engine.startNewGame('Test Ltd');
      var heard = 0;
      engine.addListener(() => heard++);

      expect(await engine.sellVehicle(starterId()), isNull);

      expect(db.vehicles.count, 0);
      expect(db.company.load()!.cash, 1500000 + starterSale);
      expect(db.pending.load(), isNull);
      expect(heard, 1);
      expect(engine.snapshot.vehicles, isEmpty);
    });

    test('unassign, let the trip finish, then sell', () async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
      final id = starterId();
      await engine.assignVehicle(id, routeId: 'R01', cargoName: 'General dry');

      // On the road: no sale.
      final refused = await engine.sellVehicle(id);
      expect(refused!.reason, SaleRejectionReason.vehicleOnTheRoad);

      expect(await engine.unassignVehicle(id), true);
      expect(db.vehicles.get(id)!.isAssigned, false);
      expect(db.trips.activeFor(id), isNotNull, reason: 'the trip goes on');
      expect(
        (await engine.sellVehicle(id))!.reason,
        SaleRejectionReason.vehicleOnTheRoad,
      );

      // The trip arrives, is paid, and the vehicle stays home.
      clock.advance(const Duration(seconds: 100));
      await engine.tick();
      expect(db.trips.activeFor(id), isNull);
      expect(db.trips.count, 1, reason: 'no new trip after unassigning');
      expect(db.company.load()!.cash, 1500000 + profitPerTrip);

      expect(await engine.sellVehicle(id), isNull);
      expect(db.vehicles.get(id), isNull);
      expect(db.company.load()!.cash, 1500000 + profitPerTrip + starterSale);

      // A second tap on the same sale changes nothing.
      final again = await engine.sellVehicle(id);
      expect(again!.reason, SaleRejectionReason.notOwned);
      expect(db.company.load()!.cash, 1500000 + profitPerTrip + starterSale);
    });

    test('unassigning a vehicle that waits for demand keeps it home', () async {
      await engine.startNewGame('Test Ltd');
      // Today's R01 demand is used up; tomorrow it resets to 60 t.
      await db.routeStates.put(
        RouteState(
          routeId: 'R01',
          demandRemainingT: 0,
          updatedAt: clock.now(),
          gameDay: 0,
        ),
      );
      final id = starterId();
      // A second vehicle waits on the same route and stays assigned.
      final control = (await engine.buyVehicle(2)).vehicle!.id;
      for (final v in [id, control]) {
        final outcome = await engine.assignVehicle(
          v,
          routeId: 'R01',
          cargoName: 'Parcels',
        );
        expect(outcome.plan, isA<DispatchWaiting>(), reason: v);
      }

      expect(await engine.unassignVehicle(id), true);
      expect(db.vehicles.get(id)!.isAssigned, false);
      // The next day brings demand: the assigned one goes, the other stays.
      clock.advance(const Duration(hours: 1));
      await engine.tick();
      expect(db.trips.forVehicle(control), isNotEmpty);
      expect(db.trips.forVehicle(id), isEmpty);
      expect(await engine.sellVehicle(id), isNull);
    });

    test('unassigning an idle or unknown vehicle', () async {
      await engine.startNewGame('Test Ltd');
      var heard = 0;
      engine.addListener(() => heard++);
      expect(await engine.unassignVehicle(starterId()), true);
      expect(heard, 0, reason: 'nothing changed');
      expect(await engine.unassignVehicle('nope'), false);
    });

    test('a sale frees a garage slot', () async {
      await engine.startNewGame('Test Ltd');
      final vans = [
        for (var i = 0; i < 5; i++) (await engine.buyVehicle(1)).vehicle!,
      ];
      expect(
        (await engine.buyVehicle(1)).rejection!.reason,
        PurchaseRejectionReason.noFreeGarageSlot,
      );
      expect(await engine.sellVehicle(vans.first.id), isNull);
      expect((await engine.buyVehicle(1)).bought, true);
      expect(db.vehicles.count, 6);
      // Five vans at Tk 20,000, one sold for Tk 12,000, one more bought.
      expect(db.company.load()!.cash, 1500000 - 6 * 20000 + 12000);
    });

    test('without a game selling is a programming error', () async {
      expect(() => engine.sellVehicle('v1'), throwsStateError);
      expect(() => engine.unassignVehicle('v1'), throwsStateError);
    });

    test('a new game marks only its free vehicle as the starter', () async {
      await engine.startNewGame('Test Ltd');
      expect(db.vehicles.all().single.isStarter, true);
      final bought = (await engine.buyVehicle(4)).vehicle!;
      expect(db.vehicles.get(bought.id)!.isStarter, false);

      // A bought Sathi Plus sells for 60 percent, the starter for Tk 1.5 lakh.
      final before = db.company.load()!.cash;
      expect(await engine.sellVehicle(bought.id), isNull);
      expect(db.company.load()!.cash, before + 780000);
      expect(await engine.sellVehicle(starterId()), isNull);
      expect(db.company.load()!.cash, before + 780000 + starterSale);
    });
  });

  group('selling the last vehicle', () {
    // The Sonar Van, Tk 20,000, is the cheapest vehicle open at the start.
    // A starter that sells for nothing makes the edge easy to hit.
    GameEngine engineWith(int startingCash) => makeEngine(
      config: quietConfig((j) {
        j['settings']['startingCash'] = startingCash;
        j['settings']['starterSaleValue'] = 0;
      }),
    );

    String onlyVehicle() => db.vehicles.all().single.id;

    test('one Taka short of the cheapest vehicle is refused', () async {
      engine.dispose();
      engine = engineWith(19999);
      await engine.startNewGame('Test Ltd');
      var heard = 0;
      engine.addListener(() => heard++);

      final refused = await engine.sellVehicle(onlyVehicle());

      expect(refused!.reason, SaleRejectionReason.lastVehicleUnaffordable);
      expect(db.vehicles.count, 1, reason: 'nothing was sold');
      expect(db.company.load()!.cash, 19999);
      expect(heard, 0);
    });

    test('exactly the cheapest price after the sale is allowed', () async {
      engine.dispose();
      engine = engineWith(20000);
      await engine.startNewGame('Test Ltd');

      expect(await engine.sellVehicle(onlyVehicle()), isNull);
      expect(db.vehicles.count, 0);
      expect(db.company.load()!.cash, 20000);
      // And the company can still buy its way back.
      expect((await engine.buyVehicle(1)).bought, true);
    });

    test('a bought last vehicle is guarded too', () async {
      engine.dispose();
      engine = engineWith(20000);
      await engine.startNewGame('Test Ltd');
      await engine.sellVehicle(onlyVehicle());
      final van = (await engine.buyVehicle(1)).vehicle!;
      expect(db.company.load()!.cash, 0);

      // The van resells for Tk 12,000, less than a new one costs.
      final refused = await engine.sellVehicle(van.id);
      expect(refused!.reason, SaleRejectionReason.lastVehicleUnaffordable);
      expect(db.vehicles.get(van.id), isNotNull);
    });

    test('with a second vehicle the guard does not apply', () async {
      engine.dispose();
      engine = engineWith(20000);
      await engine.startNewGame('Test Ltd');
      final starter = onlyVehicle();
      await engine.buyVehicle(1);
      expect(db.company.load()!.cash, 0);
      expect(await engine.sellVehicle(starter), isNull);
      expect(db.vehicles.count, 1);
    });
  });

  group('pruning the trip history', () {
    late String starter;

    setUp(() async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
      starter = db.vehicles.all().single.id;
      await engine.assignVehicle(
        starter,
        routeId: 'R01',
        cargoName: 'General dry',
      );
    });

    List<Trip> settledOnDisk() =>
        db.trips.all().where((t) => t.settled).toList();

    test('below 550 settled trips nothing is pruned', () async {
      // 550 trips of 84 s.
      clock.advance(const Duration(seconds: 550 * 84 + 10));
      await engine.tick();
      expect(settledOnDisk(), hasLength(550));
      clock.advance(const Duration(seconds: 30));
      await engine.tick();
      expect(settledOnDisk(), hasLength(550), reason: 'no new arrival yet');
    });

    test('past 550 the history is cut to the newest 500', () async {
      clock.advance(const Duration(hours: 13));
      await engine.tick();
      final before = settledOnDisk();
      expect(before.length, greaterThan(550));

      // Pruning rides along with the next settlement.
      clock.advance(const Duration(seconds: 100));
      await engine.tick();
      final company = db.company.load()!;
      final kept = settledOnDisk();
      final newlySettled = company.completedTrips - before.length;
      expect(newlySettled, greaterThan(0));
      expect(kept, hasLength(GameEngine.keptSettledTrips + newlySettled));

      // The oldest went, the newest stayed.
      final keptIds = {for (final t in kept) t.id};
      final pruned = before.where((t) => !keptIds.contains(t.id)).toList();
      expect(pruned, hasLength(before.length - GameEngine.keptSettledTrips));
      final newestPruned = pruned
          .map((t) => t.arriveAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      expect(kept.every((t) => t.arriveAt.isAfter(newestPruned)), true);

      // The trip on the road is never pruned.
      expect(db.trips.activeFor(starter), isNotNull);
    });

    test('pruning keeps every trip counted', () async {
      clock.advance(const Duration(hours: 13));
      await engine.tick();
      clock.advance(const Duration(seconds: 100));
      await engine.tick();

      final company = db.company.load()!;
      expect(settledOnDisk().length, lessThan(company.completedTrips));
      expect(company.lifetimeProfit, company.completedTrips * profitPerTrip);
      final days = db.dayRollups.all();
      expect(days.fold<int>(0, (s, d) => s + d.trips), company.completedTrips);
      expect(days.fold<int>(0, (s, d) => s + d.profit), company.lifetimeProfit);
      expect(company.cash, 1500000 + company.lifetimeProfit);
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

  group('a save that fails while the app keeps running', () {
    // The commit throws once, right after [failAfter], like a disk error.
    // The app does not restart: the next operation runs on the same engine.
    CommitStep? failAfter;

    setUp(() {
      failAfter = null;
      engine.dispose();
      engine = makeEngine(
        committer: ChangeCommitter(
          db,
          afterStep: (step) {
            if (step == failAfter) {
              failAfter = null;
              throw StateError('disk error after ${step.name}');
            }
          },
        ),
      );
    });

    /// Every settled trip is paid once: cash, trip count, lifetime totals and
    /// day rollups all agree with the trips on disk. [spent] is what was paid
    /// for purchases.
    void expectPaidOnce({int spent = 0}) {
      final settled = db.trips.all().where((t) => t.settled).toList();
      final company = db.company.load()!;
      expect(company.completedTrips, settled.length, reason: 'trip count');
      expect(
        company.cash,
        1500000 + settled.length * profitPerTrip - spent,
        reason: 'cash',
      );
      expect(company.lifetimeProfit, settled.length * profitPerTrip);
      expect(
        db.dayRollups.all().fold<int>(0, (s, d) => s + d.trips),
        settled.length,
        reason: 'day rollups',
      );
      expect(db.pending.load(), isNull);
    }

    Future<void> sendStarterToWork() async {
      await engine.startNewGame('Test Ltd');
      await finishTurbo();
      await engine.assignVehicle(
        db.vehicles.all().single.id,
        routeId: 'R01',
        cargoName: 'General dry',
      );
    }

    for (final step in CommitStep.values) {
      test(
        'a payout fails after ${step.name}: the next tick pays once',
        () async {
          await sendStarterToWork();
          clock.advance(const Duration(seconds: 100));
          failAfter = step;
          await expectLater(engine.tick(), throwsStateError);

          // Time moves on and the loop ticks again.
          clock.advance(const Duration(seconds: 100));
          await engine.tick();
          expect(db.company.load()!.completedTrips, 2);
          expectPaidOnce();
        },
      );

      test(
        'a payout fails after ${step.name}: a purchase comes next',
        () async {
          await sendStarterToWork();
          clock.advance(const Duration(seconds: 100));
          failAfter = step;
          await expectLater(engine.tick(), throwsStateError);

          expect((await engine.buyVehicle(2)).bought, true);
          expectPaidOnce(spent: 150000);
          expect(db.vehicles.count, 2);
        },
      );

      test(
        'a purchase fails after ${step.name}: the next one pays too',
        () async {
          await engine.startNewGame('Test Ltd');
          failAfter = step;
          await expectLater(engine.buyVehicle(2), throwsStateError);

          expect((await engine.buyVehicle(2)).bought, true);
          // Both vans are in the garage and both were paid for, once each.
          expect(db.vehicles.byTier(2), hasLength(2));
          expect(db.company.load()!.cash, 1500000 - 2 * 150000);
          expect(db.pending.load(), isNull);
        },
      );
    }
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
