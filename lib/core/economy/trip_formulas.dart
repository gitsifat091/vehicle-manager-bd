/// The formulas from CLAUDE.md "Core formulas", one function each.
/// All values are unrounded doubles. Round only when storing or displaying.
/// Pure Dart: no Flutter imports.
library;

import 'dart:math' as math;

import '../config/economy_config.dart';

/// Load carried = legal payload + overload, capped at the vehicle's max load.
double loadCarried(VehicleSpec vehicle, double overloadT) {
  return math.min(vehicle.legalPayloadT + overloadT, vehicle.maxLoadT);
}

/// Overload ratio = (load - legal payload) / legal payload. Never negative.
double overloadRatio(VehicleSpec vehicle, double loadT) {
  final over = loadT - vehicle.legalPayloadT;
  return over <= 0 ? 0 : over / vehicle.legalPayloadT;
}

/// Tons carried above the legal payload. Never negative.
double tonsOver(VehicleSpec vehicle, double loadT) {
  return math.max(0, loadT - vehicle.legalPayloadT);
}

/// Driven km = one-way km x 2 for Local hauls, one-way km for Line hauls.
double drivenKm(RouteSpec route) {
  return route.haulType == HaulType.local
      ? route.distanceKm * 2
      : route.distanceKm;
}

/// Revenue = load x (baseFarePerTon + ratePerTonKm x one-way km)
///           x cargo rateFactor x smallLoadPremium x freightMultiplier.
double revenue({
  required EconomySettings settings,
  required VehicleSpec vehicle,
  required RouteSpec route,
  required CargoSpec cargo,
  required double loadT,
}) {
  final farePerTon =
      settings.baseFarePerTon + settings.ratePerTonKm * route.distanceKm;
  return loadT *
      farePerTon *
      cargo.rateFactor *
      vehicle.smallLoadPremium *
      settings.freightMultiplier;
}

/// Energy = driven km x (diesel price / mileage, or otherEnergyTkPerKm when
/// mileage is 0) x (1 + extraFuelPerFullOverload x overload ratio).
double energyCost({
  required EconomySettings settings,
  required VehicleSpec vehicle,
  required double drivenKm,
  required double overloadRatio,
}) {
  final perKm = vehicle.mileageKmPerL > 0
      ? settings.dieselPricePerLitre / vehicle.mileageKmPerL
      : vehicle.otherEnergyTkPerKm;
  return drivenKm *
      perKm *
      (1 + settings.extraFuelPerFullOverload * overloadRatio);
}

/// Toll = toll table[vehicle tollClass][route crossing], doubled for Local.
double tollCost({
  required EconomyConfig config,
  required VehicleSpec vehicle,
  required RouteSpec route,
}) {
  final oneWay = config.tollFor(vehicle.tollClass, route.crossing);
  return route.haulType == HaulType.local ? oneWay * 2 : oneWay;
}

/// Trip time (game hours) = driven km / speed + load time + route extra delay.
double tripGameHours({required VehicleSpec vehicle, required RouteSpec route}) {
  return drivenKm(route) / vehicle.speedKmh +
      vehicle.loadTimeGameH +
      route.extraDelayGameH;
}

/// Crew = trip time x crew wage per game hour.
double crewCost({required VehicleSpec vehicle, required double tripHours}) {
  return tripHours * vehicle.crewWageTkPerGameHour;
}

/// Maintenance = driven km x maintenance per km
///               x (1 + extraWearPerFullOverload x overload ratio).
double maintenanceCost({
  required EconomySettings settings,
  required VehicleSpec vehicle,
  required double drivenKm,
  required double overloadRatio,
}) {
  return drivenKm *
      vehicle.maintenanceTkPerKm *
      (1 + settings.extraWearPerFullOverload * overloadRatio);
}

/// Fine for one weighbridge check that catches the truck:
/// fine base + fine per ton x tons over. Zero when not overloaded.
/// The game rolls each weighbridge separately and charges this amount.
double overloadFineIfCaught({
  required EconomySettings settings,
  required double tonsOver,
}) {
  if (tonsOver <= 0) return 0;
  return settings.overloadFineBase + settings.overloadFinePerTon * tonsOver;
}

/// Expected fines = weighbridges x check chance x fine if caught.
double expectedOverloadFines({
  required EconomySettings settings,
  required RouteSpec route,
  required double tonsOver,
}) {
  return route.weighbridges *
      settings.weighbridgeCheckChance *
      overloadFineIfCaught(settings: settings, tonsOver: tonsOver);
}

/// Accident chance = accidentChancePer100Km x driven km / 100
///                   x (1 + growth x overload ratio). Capped at 1.
double accidentChance({
  required EconomySettings settings,
  required double drivenKm,
  required double overloadRatio,
}) {
  final chance =
      settings.accidentChancePer100Km *
      drivenKm /
      100 *
      (1 + settings.accidentGrowthPerFullOverload * overloadRatio);
  return math.min(1, chance);
}

/// Accident cost = price x accidentCostShareOfPrice.
double accidentCostIfHit({
  required EconomySettings settings,
  required VehicleSpec vehicle,
}) {
  return vehicle.priceTk * settings.accidentCostShareOfPrice;
}
