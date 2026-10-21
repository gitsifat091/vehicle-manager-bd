import 'dart:math';

import '../../data/models/models.dart';
import '../config/economy_config.dart';
import '../economy/trip_planner.dart';

/// A trip that has been paid out, with what the dice decided.
class SettlementResult {
  const SettlementResult({
    required this.trip,
    required this.weighbridgesCaught,
    required this.hadAccident,
  });

  /// The trip with [Trip.settled] true and its final fines and accident cost.
  final Trip trip;
  final int weighbridgesCaught;
  final bool hadAccident;
}

/// Settles an arrived trip: rolls the overload fine at each weighbridge and
/// the accident chance, and returns the trip with its final costs.
///
/// Dice order, so a seeded [random] gives repeatable results:
/// 1. one roll per weighbridge, in route order (only if the trip is overloaded)
/// 2. one roll for the accident (always)
///
/// Revenue and the other costs stay as they were at dispatch. If the vehicle,
/// route or cargo is no longer in the config, the trip settles with the
/// expected costs it was dispatched with.
SettlementResult settleTrip({
  required EconomyConfig config,
  required Trip trip,
  required Random random,
}) {
  final quote = _requote(config, trip);
  if (quote == null) {
    return SettlementResult(
      trip: trip.copyWith(settled: true),
      weighbridgesCaught: 0,
      hadAccident: false,
    );
  }

  var caught = 0;
  if (quote.fineIfCaught > 0) {
    final weighbridges = config.routeById(trip.routeId).weighbridges;
    for (var i = 0; i < weighbridges; i++) {
      if (random.nextDouble() < config.settings.weighbridgeCheckChance) {
        caught++;
      }
    }
  }
  final accident = random.nextDouble() < quote.accidentChance;

  final old = trip.costs;
  final costs = TripCosts(
    energy: old.energy,
    toll: old.toll,
    crew: old.crew,
    maintenance: old.maintenance,
    fines: (caught * quote.fineIfCaught).round(),
    accident: accident ? quote.accidentCostIfHit.round() : 0,
  );
  return SettlementResult(
    trip: trip.copyWith(costs: costs, settled: true),
    weighbridgesCaught: caught,
    hadAccident: accident,
  );
}

/// Rebuilds the quote the trip was dispatched with, or null when the config
/// no longer knows its vehicle, route or cargo.
TripQuote? _requote(EconomyConfig config, Trip trip) {
  final vehicles = config.vehicles.where((v) => v.tier == trip.vehicleTier);
  final routes = config.routes.where((r) => r.id == trip.routeId);
  final cargos = config.cargo.where((c) => c.name == trip.cargo);
  if (vehicles.isEmpty || routes.isEmpty || cargos.isEmpty) return null;
  final vehicle = vehicles.first;
  try {
    return quoteTrip(
      config: config,
      vehicle: vehicle,
      route: routes.first,
      cargo: cargos.first,
      overloadT: trip.loadT > vehicle.legalPayloadT
          ? trip.loadT - vehicle.legalPayloadT
          : 0,
      loadLimitT: trip.loadT,
    );
  } on TripRejectedException {
    return null;
  }
}
