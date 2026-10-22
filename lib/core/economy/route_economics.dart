import '../config/economy_config.dart';
import 'trip_planner.dart';

/// Game hours in one game day (CLAUDE.md, time model).
const double gameHoursPerDay = 24;

/// What one vehicle earns on one route with one cargo when it runs back to
/// back at its legal payload, with expected fines and accidents. The basis of
/// the demand preview on the buy screen, and the same definition as the
/// economy sheet's payback (Trip Calculator, column AA).
///
/// Per-hour figures are real hours at 1x. Turbo Start makes them pass faster
/// but does not change tons per game day, because trips and days speed up
/// together.
class RouteEconomics {
  const RouteEconomics({
    required this.vehicle,
    required this.route,
    required this.cargo,
    required this.quote,
    required this.gameMinutesPerRealMinute,
  });

  final VehicleSpec vehicle;
  final RouteSpec route;
  final CargoSpec cargo;
  final TripQuote quote;
  final double gameMinutesPerRealMinute;

  /// Real hours one trip takes at 1x.
  double get tripRealHours => quote.tripGameHours / gameMinutesPerRealMinute;

  /// Expected profit per real hour at 1x.
  double get profitPerRealHour => quote.profit / tripRealHours;

  /// Tons the vehicle moves per game day, which is what it takes from the
  /// route's daily demand.
  double get tonsPerGameDay =>
      gameHoursPerDay / quote.tripGameHours * quote.loadT;

  /// Real hours at 1x until the profit pays the vehicle's price, or null when
  /// the trip loses money.
  double? get paybackRealHours =>
      profitPerRealHour > 0 ? vehicle.priceTk / profitPerRealHour : null;

  /// How many of this vehicle the route's full daily demand keeps busy. Below
  /// 1 one vehicle already runs out of cargo before the day ends.
  double get vehiclesRouteHolds => route.dailyDemandT / tonsPerGameDay;
}

/// The economics of [vehicle] on [route] with [cargo].
///
/// Throws [TripRejectedException] when the trip is not allowed. Call
/// [checkTripEligibility] first to get the reason without an exception.
RouteEconomics routeEconomics({
  required EconomyConfig config,
  required VehicleSpec vehicle,
  required RouteSpec route,
  required CargoSpec cargo,
}) {
  return RouteEconomics(
    vehicle: vehicle,
    route: route,
    cargo: cargo,
    quote: quoteTrip(
      config: config,
      vehicle: vehicle,
      route: route,
      cargo: cargo,
    ),
    gameMinutesPerRealMinute: config.settings.gameMinutesPerRealMinute,
  );
}

/// Every cargo [vehicle] may carry on [route], in config order. Empty when it
/// cannot run the route at all.
List<RouteEconomics> allCargoOn({
  required EconomyConfig config,
  required VehicleSpec vehicle,
  required RouteSpec route,
}) {
  return [
    for (final cargo in config.cargo)
      if (checkTripEligibility(
            settings: config.settings,
            vehicle: vehicle,
            route: route,
            cargo: cargo,
          ) ==
          null)
        routeEconomics(
          config: config,
          vehicle: vehicle,
          route: route,
          cargo: cargo,
        ),
  ];
}

/// The cargo with the highest profit per real hour for [vehicle] on [route],
/// or null when it cannot run the route. The best can still lose money; check
/// [RouteEconomics.paybackRealHours]. On a tie the first cargo in config
/// order wins.
RouteEconomics? bestCargoOn({
  required EconomyConfig config,
  required VehicleSpec vehicle,
  required RouteSpec route,
}) {
  RouteEconomics? best;
  for (final e in allCargoOn(config: config, vehicle: vehicle, route: route)) {
    if (best == null || e.profitPerRealHour > best.profitPerRealHour) {
      best = e;
    }
  }
  return best;
}

/// The best cargo on every route [vehicle] can run, in config route order.
List<RouteEconomics> bestCargoPerRoute({
  required EconomyConfig config,
  required VehicleSpec vehicle,
}) {
  return [
    for (final route in config.routes)
      ?bestCargoOn(config: config, vehicle: vehicle, route: route),
  ];
}

/// Tons per game day the [fleet] takes from each route, by route id. Routes
/// nobody runs are missing.
Map<String, double> tonsPerGameDayByRoute(Iterable<RouteEconomics> fleet) {
  final out = <String, double>{};
  for (final e in fleet) {
    out[e.route.id] = (out[e.route.id] ?? 0) + e.tonsPerGameDay;
  }
  return out;
}

/// A route's daily demand against what the fleet already takes from it.
class RouteDemand {
  const RouteDemand({required this.route, required this.usedTonsPerGameDay});

  final RouteSpec route;

  /// Tons per game day the vehicles already on the route take.
  final double usedTonsPerGameDay;

  double get dailyDemandT => route.dailyDemandT;

  /// Demand nobody takes yet. Never below zero.
  double get spareTonsPerGameDay {
    final spare = dailyDemandT - usedTonsPerGameDay;
    return spare < 0 ? 0 : spare;
  }

  /// Whether one more vehicle running [e] would stay busy all day without
  /// running the route dry for the others.
  bool fits(RouteEconomics e) => spareTonsPerGameDay >= e.tonsPerGameDay;

  /// How many more vehicles running [e] the spare demand keeps busy.
  int vehiclesThatFit(RouteEconomics e) =>
      (spareTonsPerGameDay / e.tonsPerGameDay).floor();
}
