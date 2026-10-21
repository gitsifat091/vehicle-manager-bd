import '../config/economy_config.dart';
import 'trip_formulas.dart' as f;
import 'trip_quote.dart';
import 'trip_rejection.dart';

export 'trip_quote.dart';
export 'trip_rejection.dart';

/// Returns why [vehicle] cannot run [route] with [cargo], or null when the trip
/// is allowed.
///
/// Line hauls are limited by settings.maxLineHaulKm, and cargo.allowedTiers
/// decides which vehicles can carry which cargo.
///
/// A route needs highway access when it is a Line haul or crosses a bridge or
/// ferry. Vehicles with highwayAllowed false (tier 1 and 2) are rejected there.
TripRejection? checkTripEligibility({
  required EconomySettings settings,
  required VehicleSpec vehicle,
  required RouteSpec route,
  required CargoSpec cargo,
  double overloadT = 0,
}) {
  if (overloadT < 0) {
    return TripRejection(
      TripRejectionReason.negativeOverload,
      'Overload cannot be negative (got $overloadT t).',
    );
  }
  if (route.haulType == HaulType.line &&
      route.distanceKm > settings.maxLineHaulKm) {
    return TripRejection(
      TripRejectionReason.lineHaulTooLong,
      'Route ${route.id} is a Line haul of ${route.distanceKm} km, '
      'above the ${settings.maxLineHaulKm} km limit.',
    );
  }
  final needsHighway =
      route.haulType == HaulType.line || route.crossing != 'None';
  if (needsHighway && !vehicle.highwayAllowed) {
    return TripRejection(
      TripRejectionReason.vehicleNotAllowedOnHighway,
      '${vehicle.name} (tier ${vehicle.tier}) is not allowed on the highway, '
      'so it cannot run route ${route.id}.',
    );
  }
  if (!cargo.allowedTiers.contains(vehicle.tier)) {
    return TripRejection(
      TripRejectionReason.cargoNotAllowedForVehicle,
      '${vehicle.name} (tier ${vehicle.tier}) cannot carry ${cargo.name}. '
      'Allowed tiers: ${cargo.allowedTiers.join(', ')}.',
    );
  }
  return null;
}

/// Expected economics of one trip of [vehicle] on [route] carrying [cargo].
///
/// [overloadT] is tons above the legal payload. The load is capped at the
/// vehicle's max load, so a tanker (legal payload equals max load) cannot
/// overload. Fines and accidents are expected values; the sim rolls them.
///
/// [loadLimitT] caps the load further, for example at the demand left on the
/// route. The trip then carries what is left, even below the legal payload.
///
/// Throws [TripRejectedException] when the trip is not allowed. Call
/// [checkTripEligibility] first to get the reason without an exception.
TripQuote quoteTrip({
  required EconomyConfig config,
  required VehicleSpec vehicle,
  required RouteSpec route,
  required CargoSpec cargo,
  double overloadT = 0,
  double? loadLimitT,
}) {
  final rejection = checkTripEligibility(
    settings: config.settings,
    vehicle: vehicle,
    route: route,
    cargo: cargo,
    overloadT: overloadT,
  );
  if (rejection != null) throw TripRejectedException(rejection);

  final s = config.settings;
  final loadT = f.loadCarried(vehicle, overloadT, limitT: loadLimitT);
  final ratio = f.overloadRatio(vehicle, loadT);
  final over = f.tonsOver(vehicle, loadT);
  final km = f.drivenKm(route);
  final hours = f.tripGameHours(vehicle: vehicle, route: route);
  final chance = f.accidentChance(
    settings: s,
    drivenKm: km,
    overloadRatio: ratio,
  );
  final accidentCost = f.accidentCostIfHit(settings: s, vehicle: vehicle);

  return TripQuote(
    vehicleTier: vehicle.tier,
    routeId: route.id,
    cargoName: cargo.name,
    loadT: loadT,
    tonsOver: over,
    overloadRatio: ratio,
    drivenKm: km,
    tripGameHours: hours,
    revenue: f.revenue(
      settings: s,
      vehicle: vehicle,
      route: route,
      cargo: cargo,
      loadT: loadT,
    ),
    energy: f.energyCost(
      settings: s,
      vehicle: vehicle,
      drivenKm: km,
      overloadRatio: ratio,
    ),
    toll: f.tollCost(config: config, vehicle: vehicle, route: route),
    crew: f.crewCost(vehicle: vehicle, tripHours: hours),
    maintenance: f.maintenanceCost(
      settings: s,
      vehicle: vehicle,
      drivenKm: km,
      overloadRatio: ratio,
    ),
    expectedFines: f.expectedOverloadFines(
      settings: s,
      route: route,
      tonsOver: over,
    ),
    expectedAccident: chance * accidentCost,
    fineIfCaught: f.overloadFineIfCaught(settings: s, tonsOver: over),
    accidentChance: chance,
    accidentCostIfHit: accidentCost,
  );
}
