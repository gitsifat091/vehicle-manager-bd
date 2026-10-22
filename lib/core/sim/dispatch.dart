import '../../data/models/models.dart';
import '../config/economy_config.dart';
import '../economy/trip_planner.dart';
import 'game_calendar.dart';
import 'trip_timing.dart';

/// Demand smaller than this counts as none left (floating point leftovers).
const double _demandEpsilonT = 1e-6;

/// What happens when a vehicle tries to depart.
sealed class DispatchPlan {
  const DispatchPlan();
}

/// The vehicle departs: [trip] is new and [routeState] has the demand used.
class DispatchReady extends DispatchPlan {
  const DispatchReady({
    required this.trip,
    required this.routeState,
    required this.quote,
  });

  final Trip trip;
  final RouteState routeState;
  final TripQuote quote;
}

/// No demand is left on the route today. The vehicle waits until [until],
/// the start of the next game day, when demand resets.
class DispatchWaiting extends DispatchPlan {
  const DispatchWaiting(this.until);

  final DateTime until;
}

/// The vehicle may not run this route and cargo.
class DispatchRejected extends DispatchPlan {
  const DispatchRejected(this.rejection);

  final TripRejection rejection;
}

enum DispatchBlockReason { unknownVehicle, notAssigned, onTheRoad }

/// The vehicle cannot depart for a reason that is not about the route.
class DispatchBlocked extends DispatchPlan {
  const DispatchBlocked(this.reason);

  final DispatchBlockReason reason;
}

/// The route's demand as it stands at [t]. At a game day boundary it resets to
/// the full daily demand. A route with no saved state starts full.
///
/// The returned state always has its [RouteState.gameDay] set. If [t] is
/// earlier than the saved state, the saved state is used as it is.
RouteState routeDemandAt({
  required RouteSpec route,
  required RouteState? saved,
  required DateTime t,
  required GameCalendar calendar,
}) {
  final today = calendar.dayIndex(t);
  final current = saved ?? RouteState.initial(route, t, gameDay: today);
  // Old saves have no day number. The day of their timestamp is the best guess.
  final savedDay = current.gameDay ?? calendar.dayIndex(current.updatedAt);
  if (today > savedDay) {
    return RouteState(
      routeId: route.id,
      demandRemainingT: route.dailyDemandT,
      updatedAt: t,
      gameDay: today,
    );
  }
  return current.copyWith(gameDay: savedDay);
}

/// Plans one departure of [vehicle] at [departAt] on its assigned route.
///
/// The trip is quoted with the economy engine. It takes the demand left on the
/// route: if that is less than the load, it carries what is left; if it is
/// zero, the vehicle waits for the next game day. Arrival is the departure
/// plus the real duration at [turboSpeed].
DispatchPlan planDispatch({
  required EconomyConfig config,
  required GameCalendar calendar,
  required Vehicle vehicle,
  required RouteState? routeState,
  required DateTime departAt,
  required double turboSpeed,
  required String Function() newTripId,
}) {
  final routeId = vehicle.assignedRouteId;
  final cargoName = vehicle.assignedCargo;
  if (routeId == null || cargoName == null) {
    return const DispatchBlocked(DispatchBlockReason.notAssigned);
  }
  final spec = config.vehicleByTier(vehicle.tier);
  final route = config.routeById(routeId);
  final cargo = config.cargoByName(cargoName);

  final rejection = checkTripEligibility(
    settings: config.settings,
    vehicle: spec,
    route: route,
    cargo: cargo,
    overloadT: vehicle.overloadT,
  );
  if (rejection != null) return DispatchRejected(rejection);

  final demand = routeDemandAt(
    route: route,
    saved: routeState,
    t: departAt,
    calendar: calendar,
  );
  if (demand.demandRemainingT < _demandEpsilonT) {
    return DispatchWaiting(calendar.nextDayStart(departAt));
  }

  final quote = quoteTrip(
    config: config,
    vehicle: spec,
    route: route,
    cargo: cargo,
    overloadT: vehicle.overloadT,
    loadLimitT: demand.demandRemainingT,
  );
  final duration = realTripDuration(
    settings: config.settings,
    gameHours: quote.tripGameHours,
    turboSpeed: turboSpeed,
  );
  final trip = Trip(
    id: newTripId(),
    vehicleId: vehicle.id,
    vehicleTier: vehicle.tier,
    routeId: route.id,
    cargo: cargo.name,
    loadT: quote.loadT,
    departAt: departAt,
    arriveAt: departAt.add(duration),
    revenue: quote.revenueTk,
    costs: TripCosts.fromQuote(quote),
  );
  final remaining = demand.demandRemainingT - quote.loadT;
  return DispatchReady(
    trip: trip,
    routeState: demand.copyWith(
      demandRemainingT: remaining < _demandEpsilonT ? 0 : remaining,
      updatedAt: departAt,
    ),
    quote: quote,
  );
}
