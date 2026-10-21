/// Immutable config classes mirroring assets/config/economy.json.
/// Pure Dart: no Flutter imports.
library;

enum HaulType {
  /// Round trip, returns empty. Distance and tolls are doubled.
  local,

  /// One way only.
  line,
}

class EconomySettings {
  const EconomySettings({
    required this.dieselPricePerLitre,
    required this.baseFarePerTon,
    required this.ratePerTonKm,
    required this.freightMultiplier,
    required this.gameMinutesPerRealMinute,
    required this.turboPhase1EndMin,
    required this.turboPhase1Speed,
    required this.turboPhase2EndMin,
    required this.turboPhase2Speed,
    required this.turboPhase3EndMin,
    required this.turboPhase3Speed,
    required this.startingCash,
    required this.firstTerminalPrice,
    required this.extraFuelPerFullOverload,
    required this.extraWearPerFullOverload,
    required this.weighbridgeCheckChance,
    required this.overloadFineBase,
    required this.overloadFinePerTon,
    required this.accidentChancePer100Km,
    required this.accidentGrowthPerFullOverload,
    required this.accidentCostShareOfPrice,
    required this.maxLineHaulKm,
  });

  final double dieselPricePerLitre;
  final double baseFarePerTon;
  final double ratePerTonKm;
  final double freightMultiplier;
  final double gameMinutesPerRealMinute;
  final int turboPhase1EndMin;
  final double turboPhase1Speed;
  final int turboPhase2EndMin;
  final double turboPhase2Speed;
  final int turboPhase3EndMin;
  final double turboPhase3Speed;
  final int startingCash;
  final int firstTerminalPrice;
  final double extraFuelPerFullOverload;
  final double extraWearPerFullOverload;
  final double weighbridgeCheckChance;
  final double overloadFineBase;
  final double overloadFinePerTon;
  final double accidentChancePer100Km;
  final double accidentGrowthPerFullOverload;
  final double accidentCostShareOfPrice;

  /// Line hauls longer than this (one-way km) are not allowed.
  final double maxLineHaulKm;
}

class VehicleSpec {
  const VehicleSpec({
    required this.tier,
    required this.name,
    required this.realWorld,
    required this.priceTk,
    required this.legalPayloadT,
    required this.maxLoadT,
    required this.speedKmh,
    required this.mileageKmPerL,
    required this.otherEnergyTkPerKm,
    required this.maintenanceTkPerKm,
    required this.crewWageTkPerGameHour,
    required this.loadTimeGameH,
    required this.smallLoadPremium,
    required this.tollClass,
    required this.highwayAllowed,
    required this.unlock,
  });

  final int tier;
  final String name;
  final String realWorld;
  final int priceTk;
  final double legalPayloadT;
  final double maxLoadT;
  final double speedKmh;

  /// Diesel mileage. 0 means the vehicle uses [otherEnergyTkPerKm] instead.
  final double mileageKmPerL;
  final double otherEnergyTkPerKm;
  final double maintenanceTkPerKm;
  final double crewWageTkPerGameHour;
  final double loadTimeGameH;
  final double smallLoadPremium;
  final String tollClass;
  final bool highwayAllowed;
  final String unlock;
}

class CargoSpec {
  const CargoSpec({
    required this.name,
    required this.rateFactor,
    required this.allowedTiers,
  });

  final String name;
  final double rateFactor;

  /// Vehicle tiers that can carry this cargo.
  final List<int> allowedTiers;
}

class RouteSpec {
  const RouteSpec({
    required this.id,
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.haulType,
    required this.crossing,
    required this.weighbridges,
    required this.extraDelayGameH,
    required this.dailyDemandT,
  });

  final String id;
  final String from;
  final String to;

  /// One-way distance.
  final double distanceKm;
  final HaulType haulType;

  /// Key into the toll table, for example "None" or "Padma Bridge".
  final String crossing;
  final int weighbridges;
  final double extraDelayGameH;
  final double dailyDemandT;
}
