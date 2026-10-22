import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';
import 'package:vehicle_manager_bd/core/sim/dispatch.dart';
import 'package:vehicle_manager_bd/core/sim/game_calendar.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../../support/sim_support.dart';
import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();
  final calendar = GameCalendar.fromSettings(config.settings, t0);

  DispatchPlan plan(
    Vehicle vehicle, {
    RouteState? state,
    DateTime? at,
    double turbo = 1,
  }) {
    return planDispatch(
      config: config,
      calendar: calendar,
      vehicle: vehicle,
      routeState: state,
      departAt: at ?? t0,
      turboSpeed: turbo,
      newTripId: () => 'trip_1',
    );
  }

  DispatchReady ready(DispatchPlan p) {
    expect(p, isA<DispatchReady>());
    return p as DispatchReady;
  }

  group('timing', () {
    test('1x: Tier 4 on R01 (1.4 game hours) takes 84 s', () {
      final r = ready(plan(assignedVehicle()));
      expect(r.trip.departAt, t0);
      expect(r.trip.arriveAt, t0.add(const Duration(seconds: 84)));
    });

    test('turbo 20x: the same trip takes 4.2 s', () {
      final r = ready(plan(assignedVehicle(), turbo: 20));
      expect(r.trip.arriveAt, t0.add(const Duration(milliseconds: 4200)));
    });

    test('turbo 5x', () {
      final r = ready(plan(assignedVehicle(), turbo: 5));
      expect(r.trip.arriveAt, t0.add(const Duration(milliseconds: 16800)));
    });

    test('Tier 6 on R05 takes 9 min 15 s at 1x and 27.75 s at 20x', () {
      final v = assignedVehicle(tier: 6, routeId: 'R05');
      expect(
        ready(plan(v)).trip.arriveAt,
        t0.add(const Duration(minutes: 9, seconds: 15)),
      );
      expect(
        ready(plan(v, turbo: 20)).trip.arriveAt,
        t0.add(const Duration(seconds: 27, milliseconds: 750)),
      );
    });

    test('departs at the time it is given, not at some other now', () {
      final at = t0.add(const Duration(minutes: 7));
      final r = ready(plan(assignedVehicle(), at: at));
      expect(r.trip.departAt, at);
      expect(r.trip.arriveAt, at.add(const Duration(seconds: 84)));
    });
  });

  group('the trip', () {
    test('matches the quote from the economy engine', () {
      final r = ready(plan(assignedVehicle()));
      expect(r.trip.id, 'trip_1');
      expect(r.trip.vehicleId, 'v1');
      expect(r.trip.vehicleTier, 4);
      expect(r.trip.routeId, 'R01');
      expect(r.trip.cargo, 'General dry');
      expect(r.trip.loadT, 1.5);
      expect(r.trip.revenue, 2693);
      expect(r.trip.settled, false);
      // Expected costs: energy 337.5, crew 112, maintenance 60, accident 78.
      expect(r.trip.costs.energy, 338);
      expect(r.trip.costs.toll, 0);
      expect(r.trip.costs.crew, 112);
      expect(r.trip.costs.maintenance, 60);
      expect(r.trip.costs.fines, 0);
      expect(r.trip.costs.accident, 78);
      expect(r.quote.profit, closeTo(2105.75, 0.01));
    });

    test('carries the overload the player chose', () {
      final r = ready(
        plan(assignedVehicle(tier: 6, routeId: 'R05', overloadT: 5)),
      );
      expect(r.trip.loadT, 15);
    });
  });

  group('demand', () {
    test('a route with no saved state starts full and the trip uses some', () {
      final r = ready(plan(assignedVehicle()));
      expect(r.routeState.routeId, 'R01');
      expect(r.routeState.demandRemainingT, closeTo(58.5, 1e-9));
      expect(r.routeState.updatedAt, t0);
    });

    test('uses the saved demand', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 10,
        updatedAt: t0,
      );
      final r = ready(plan(assignedVehicle(), state: state));
      expect(r.routeState.demandRemainingT, closeTo(8.5, 1e-9));
    });

    test('carries what is left when demand is below the load', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0.5,
        updatedAt: t0,
      );
      final r = ready(plan(assignedVehicle(), state: state));
      expect(r.trip.loadT, 0.5);
      // A third of the 1.5 t revenue (2693.25).
      expect(r.trip.revenue, 898);
      expect(r.routeState.demandRemainingT, 0);
    });

    test('waits for the next game day when demand is zero', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0,
        updatedAt: t0,
      );
      final at = t0.add(const Duration(minutes: 10));
      final p = plan(assignedVehicle(), state: state, at: at);
      expect(p, isA<DispatchWaiting>());
      expect((p as DispatchWaiting).until, t0.add(const Duration(minutes: 24)));
    });

    test('resets to the daily demand at the game day boundary', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0,
        updatedAt: t0,
      );
      final nextDay = t0.add(const Duration(minutes: 24));
      final r = ready(plan(assignedVehicle(), state: state, at: nextDay));
      expect(r.trip.loadT, 1.5);
      expect(r.routeState.demandRemainingT, closeTo(58.5, 1e-9));
      expect(r.routeState.updatedAt, nextDay);
    });

    test('does not reset one second before the boundary', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0,
        updatedAt: t0,
      );
      final almost = t0.add(const Duration(minutes: 23, seconds: 59));
      expect(
        plan(assignedVehicle(), state: state, at: almost),
        isA<DispatchWaiting>(),
      );
    });

    test('routeDemandAt resets by day, not by elapsed time', () {
      final route = config.routeById('R01');
      final late = RouteState(
        routeId: 'R01',
        demandRemainingT: 5,
        updatedAt: t0.add(const Duration(minutes: 23)),
      );
      final next = routeDemandAt(
        route: route,
        saved: late,
        t: t0.add(const Duration(minutes: 25)),
        calendar: calendar,
      );
      expect(next.demandRemainingT, 60);
    });
  });

  group('game days under turbo', () {
    // The bonus the turbo has earned after 5 foreground minutes at 20x.
    const bonus = Duration(minutes: 95);
    final turboCalendar = GameCalendar.fromSettings(
      config.settings,
      t0,
      bonus: bonus,
      now: t0.add(const Duration(minutes: 5)),
      turboSpeed: 20,
    );
    final now = t0.add(const Duration(minutes: 5));

    test('the trip stores the game day it used demand from', () {
      final r = ready(
        planDispatch(
          config: config,
          calendar: turboCalendar,
          vehicle: assignedVehicle(),
          routeState: null,
          departAt: now,
          turboSpeed: 20,
          newTripId: () => 'trip_1',
        ),
      );
      // 5 real minutes + 95 bonus = 100 game clock minutes: day 4.
      expect(r.routeState.gameDay, 4);
    });

    test('demand resets by the stored day, not by the old timestamp', () {
      // Saved in day 3, one real minute ago. Read with today's bonus, that
      // timestamp would also look like day 4, and the reset would be missed.
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0,
        updatedAt: now.subtract(const Duration(minutes: 1)),
        gameDay: 3,
      );
      final r = ready(
        planDispatch(
          config: config,
          calendar: turboCalendar,
          vehicle: assignedVehicle(),
          routeState: state,
          departAt: now,
          turboSpeed: 20,
          newTripId: () => 'trip_1',
        ),
      );
      expect(r.trip.loadT, 1.5);
      expect(r.routeState.demandRemainingT, closeTo(58.5, 1e-9));
      expect(r.routeState.gameDay, 4);
    });

    test('no reset while the stored day is still today', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0,
        updatedAt: now.subtract(const Duration(minutes: 1)),
        gameDay: 4,
      );
      final p = planDispatch(
        config: config,
        calendar: turboCalendar,
        vehicle: assignedVehicle(),
        routeState: state,
        departAt: now,
        turboSpeed: 20,
        newTripId: () => 'trip_1',
      );
      expect(p, isA<DispatchWaiting>());
    });

    test('waiting for the next day is shortened by the turbo speed', () {
      final state = RouteState(
        routeId: 'R01',
        demandRemainingT: 0,
        updatedAt: now,
        gameDay: 4,
      );
      final p = planDispatch(
        config: config,
        calendar: turboCalendar,
        vehicle: assignedVehicle(),
        routeState: state,
        departAt: now,
        turboSpeed: 20,
        newTripId: () => 'trip_1',
      );
      // The game clock reads 100 of 120 minutes: 20 game minutes left, which
      // is one real minute at 20x (24 real minutes at 1x).
      expect((p as DispatchWaiting).until, now.add(const Duration(minutes: 1)));
    });

    test('a save without a day number uses the day of its timestamp', () {
      final route = config.routeById('R01');
      final old = RouteState(
        routeId: 'R01',
        demandRemainingT: 5,
        updatedAt: t0,
      );
      final calendar = GameCalendar.fromSettings(config.settings, t0);
      final same = routeDemandAt(
        route: route,
        saved: old,
        t: t0.add(const Duration(minutes: 10)),
        calendar: calendar,
      );
      expect(same.demandRemainingT, 5);
      expect(same.gameDay, 0);
      final next = routeDemandAt(
        route: route,
        saved: old,
        t: t0.add(const Duration(minutes: 25)),
        calendar: calendar,
      );
      expect(next.demandRemainingT, 60);
      expect(next.gameDay, 1);
    });
  });

  group('no trip', () {
    test('rejected when the vehicle may not run the route', () {
      final v = assignedVehicle(tier: 1, routeId: 'R05', cargo: 'Market goods');
      final p = plan(v);
      expect(p, isA<DispatchRejected>());
      expect(
        (p as DispatchRejected).rejection.reason,
        TripRejectionReason.vehicleNotAllowedOnHighway,
      );
    });

    test('rejected when the cargo does not fit the vehicle', () {
      final p = plan(assignedVehicle(cargo: 'Fuel'));
      expect(p, isA<DispatchRejected>());
      expect(
        (p as DispatchRejected).rejection.reason,
        TripRejectionReason.cargoNotAllowedForVehicle,
      );
    });

    test('blocked when the vehicle has no assignment', () {
      final p = plan(Vehicle(id: 'v1', tier: 4, purchasedAt: t0));
      expect(p, isA<DispatchBlocked>());
      expect((p as DispatchBlocked).reason, DispatchBlockReason.notAssigned);
    });
  });
}
