import 'dart:math';

import '../../data/models/models.dart';
import '../config/economy_config.dart';
import 'dispatch.dart';
import 'game_calendar.dart';
import 'settlement.dart';

/// The state the simulator works on, loaded from the save.
class SimWorld {
  SimWorld({
    required this.company,
    required Iterable<Vehicle> vehicles,
    required Iterable<Trip> unsettledTrips,
    required Iterable<RouteState> routeStates,
  }) : vehicles = List.unmodifiable(vehicles),
       unsettledTrips = List.unmodifiable(unsettledTrips),
       routeStates = List.unmodifiable(routeStates);

  final Company company;
  final List<Vehicle> vehicles;
  final List<Trip> unsettledTrips;
  final List<RouteState> routeStates;
}

/// The result of asking one vehicle to depart now.
class DispatchOutcome {
  const DispatchOutcome(this.plan, [this.change]);

  final DispatchPlan plan;

  /// What to save, or null when nothing changes.
  final ChangeSet? change;
}

/// Moves the game forward by timestamps, never frame by frame.
///
/// [advance] settles every trip that has arrived by `now`, in time order, and
/// sends Local hauls out again back to back. The same code handles a 3 second
/// timer tick and 8 hours away from the game. It does not touch the disk: it
/// returns a [ChangeSet] for the committer to save.
class GameSimulator {
  GameSimulator({
    required this.config,
    required this.random,
    required this.newId,
    this.maxStepsPerVehicle = defaultMaxStepsPerVehicle,
  });

  /// Safety cap on departures (and waits for demand) per vehicle in one
  /// [advance] call. A long absence is finished over the next ticks.
  static const defaultMaxStepsPerVehicle = 1000;

  final EconomyConfig config;

  /// Seeded in tests so fines and accidents repeat exactly.
  final Random random;
  final String Function(String prefix) newId;
  final int maxStepsPerVehicle;

  /// Settles arrived trips and redispatches Local hauls up to [now].
  ///
  /// Events run in global time order: a trip is settled at its arrival, and
  /// the vehicle then departs again at that same instant. The loop stops when
  /// the next departure or arrival would be after [now]. [turboSpeed] is the
  /// speed for every new trip.
  ChangeSet advance({
    required SimWorld world,
    required DateTime now,
    required double turboSpeed,
  }) {
    final calendar = GameCalendar.fromSettings(
      config.settings,
      world.company.createdAt,
    );
    final vehicles = {for (final v in world.vehicles) v.id: v};
    final routeStates = {for (final r in world.routeStates) r.routeId: r};
    final open = world.unsettledTrips.toList();

    final changedVehicles = <String>{};
    final changedRoutes = <String>{};
    final changedTrips = <String, Trip>{};
    final steps = <String, int>{};
    final blocked = <String>{};
    var cash = world.company.cash;
    var completed = world.company.completedTrips;

    while (true) {
      final arrival = _nextArrival(open, now);
      final departure = _nextDeparture(
        vehicles: vehicles,
        open: open,
        steps: steps,
        blocked: blocked,
        now: now,
      );
      if (arrival == null && departure == null) break;

      final arrivalFirst =
          departure == null ||
          (arrival != null &&
              !arrival.arriveAt.isAfter(departure.availableAt!));

      if (arrivalFirst) {
        open.remove(arrival);
        final settled = settleTrip(
          config: config,
          trip: arrival!,
          random: random,
        );
        changedTrips[settled.trip.id] = settled.trip;
        cash += settled.trip.profit;
        completed++;
        final vehicle = vehicles[arrival.vehicleId];
        if (vehicle != null && vehicle.isAssigned) {
          vehicles[vehicle.id] = vehicle.withAvailableAt(arrival.arriveAt);
          changedVehicles.add(vehicle.id);
        }
        continue;
      }

      final vehicle = departure;
      steps[vehicle.id] = (steps[vehicle.id] ?? 0) + 1;
      final plan = planDispatch(
        config: config,
        calendar: calendar,
        vehicle: vehicle,
        routeState: routeStates[vehicle.assignedRouteId],
        departAt: vehicle.availableAt!,
        turboSpeed: turboSpeed,
        newTripId: () => newId('trip'),
      );
      switch (plan) {
        case DispatchReady():
          open.add(plan.trip);
          changedTrips[plan.trip.id] = plan.trip;
          routeStates[plan.routeState.routeId] = plan.routeState;
          changedRoutes.add(plan.routeState.routeId);
        case DispatchWaiting():
          vehicles[vehicle.id] = vehicle.withAvailableAt(plan.until);
          changedVehicles.add(vehicle.id);
        case DispatchRejected() || DispatchBlocked():
          blocked.add(vehicle.id);
      }
    }

    return ChangeSet(
      cashAfter: cash,
      completedTripsAfter: completed,
      vehicles: [for (final id in changedVehicles) vehicles[id]!],
      trips: changedTrips.values.toList(),
      routeStates: [for (final id in changedRoutes) routeStates[id]!],
    );
  }

  /// Sends [vehicleId] out once, departing at [now]. Used when the player
  /// assigns a route or taps dispatch. The vehicle must be assigned and idle.
  ///
  /// The returned change always carries the vehicle, so a vehicle given a new
  /// assignment in [world] is saved with it.
  DispatchOutcome dispatchNow({
    required SimWorld world,
    required String vehicleId,
    required DateTime now,
    required double turboSpeed,
  }) {
    final matches = world.vehicles.where((v) => v.id == vehicleId);
    if (matches.isEmpty) {
      return const DispatchOutcome(
        DispatchBlocked(DispatchBlockReason.unknownVehicle),
      );
    }
    final vehicle = matches.first;
    if (!vehicle.isAssigned) {
      return const DispatchOutcome(
        DispatchBlocked(DispatchBlockReason.notAssigned),
      );
    }
    if (world.unsettledTrips.any((t) => t.vehicleId == vehicleId)) {
      return const DispatchOutcome(
        DispatchBlocked(DispatchBlockReason.onTheRoad),
      );
    }

    final calendar = GameCalendar.fromSettings(
      config.settings,
      world.company.createdAt,
    );
    final savedState = world.routeStates
        .where((r) => r.routeId == vehicle.assignedRouteId)
        .firstOrNull;
    final plan = planDispatch(
      config: config,
      calendar: calendar,
      vehicle: vehicle,
      routeState: savedState,
      departAt: now,
      turboSpeed: turboSpeed,
      newTripId: () => newId('trip'),
    );

    ChangeSet change(
      Vehicle v, {
      List<Trip> trips = const [],
      List<RouteState> routes = const [],
    }) {
      return ChangeSet(
        cashAfter: world.company.cash,
        completedTripsAfter: world.company.completedTrips,
        vehicles: [v],
        trips: trips,
        routeStates: routes,
      );
    }

    switch (plan) {
      case DispatchReady():
        return DispatchOutcome(
          plan,
          change(
            vehicle.withAvailableAt(now),
            trips: [plan.trip],
            routes: [plan.routeState],
          ),
        );
      case DispatchWaiting():
        // A Local haul departs by itself when demand resets.
        return DispatchOutcome(
          plan,
          change(vehicle.withAvailableAt(plan.until)),
        );
      case DispatchRejected() || DispatchBlocked():
        return DispatchOutcome(plan);
    }
  }

  /// The open trip that arrives first, if it has arrived by [now].
  Trip? _nextArrival(List<Trip> open, DateTime now) {
    Trip? best;
    for (final trip in open) {
      if (trip.arriveAt.isAfter(now)) continue;
      if (best == null || _arrivesBefore(trip, best)) best = trip;
    }
    return best;
  }

  bool _arrivesBefore(Trip a, Trip b) {
    final byArrival = a.arriveAt.compareTo(b.arriveAt);
    if (byArrival != 0) return byArrival < 0;
    final byDeparture = a.departAt.compareTo(b.departAt);
    if (byDeparture != 0) return byDeparture < 0;
    return a.id.compareTo(b.id) < 0;
  }

  /// The idle Local-haul vehicle that is ready earliest, if ready by [now].
  Vehicle? _nextDeparture({
    required Map<String, Vehicle> vehicles,
    required List<Trip> open,
    required Map<String, int> steps,
    required Set<String> blocked,
    required DateTime now,
  }) {
    final busy = {for (final t in open) t.vehicleId};
    Vehicle? best;
    for (final vehicle in vehicles.values) {
      final ready = vehicle.availableAt;
      if (ready == null || ready.isAfter(now)) continue;
      if (busy.contains(vehicle.id) || blocked.contains(vehicle.id)) continue;
      if ((steps[vehicle.id] ?? 0) >= maxStepsPerVehicle) continue;
      if (!_repeatsByItself(vehicle)) continue;
      if (best == null) {
        best = vehicle;
        continue;
      }
      final byTime = ready.compareTo(best.availableAt!);
      if (byTime < 0 || (byTime == 0 && vehicle.id.compareTo(best.id) < 0)) {
        best = vehicle;
      }
    }
    return best;
  }

  /// Only Local hauls are redispatched without the player.
  bool _repeatsByItself(Vehicle vehicle) {
    final routeId = vehicle.assignedRouteId;
    if (routeId == null) return false;
    final matches = config.routes.where((r) => r.id == routeId);
    return matches.isNotEmpty && matches.first.haulType == HaulType.local;
  }
}
