import 'dart:convert';

import 'config_exception.dart';
import 'economy_models.dart';

export 'config_exception.dart';
export 'economy_models.dart';

/// The whole economy.json as immutable objects.
///
/// Build it with [EconomyConfig.parse], which takes the JSON text so tests can
/// run without Flutter or asset loading.
class EconomyConfig {
  EconomyConfig._({
    required this.version,
    required this.currency,
    required this.settings,
    required List<VehicleSpec> vehicles,
    required List<PermitSpec> permits,
    required List<CargoSpec> cargo,
    required Map<String, Map<String, double>> tolls,
    required List<RouteSpec> routes,
  }) : vehicles = List.unmodifiable(vehicles),
       permits = List.unmodifiable(permits),
       cargo = List.unmodifiable(cargo),
       tolls = Map<String, Map<String, double>>.unmodifiable({
         for (final e in tolls.entries)
           e.key: Map<String, double>.unmodifiable(e.value),
       }),
       routes = List.unmodifiable(routes);

  final String version;
  final String currency;
  final EconomySettings settings;
  final List<VehicleSpec> vehicles;
  final List<PermitSpec> permits;
  final List<CargoSpec> cargo;

  /// tolls[tollClass][crossing] in Taka for a one-way pass.
  final Map<String, Map<String, double>> tolls;
  final List<RouteSpec> routes;

  /// Parses the economy.json text. Throws [ConfigException] naming the exact
  /// field when something is missing or has the wrong type.
  factory EconomyConfig.parse(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw ConfigException('economy.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ConfigException('economy.json: top level must be an object');
    }
    final root = _Reader(decoded, 'economy.json');

    final settings = _parseSettings(root.object('settings'));
    final vehicles = root
        .list('vehicles')
        .map((r) => _parseVehicle(r))
        .toList();
    final permits = root.list('permits').map((r) => _parsePermit(r)).toList();
    final cargo = root.list('cargo').map((r) => _parseCargo(r)).toList();
    final routes = root.list('routes').map((r) => _parseRoute(r)).toList();
    final tolls = _parseTolls(root.object('tolls'));

    final config = EconomyConfig._(
      version: root.string('version'),
      currency: root.string('currency'),
      settings: settings,
      vehicles: vehicles,
      permits: permits,
      cargo: cargo,
      tolls: tolls,
      routes: routes,
    );
    config._validateCrossReferences();
    return config;
  }

  VehicleSpec vehicleByTier(int tier) {
    for (final v in vehicles) {
      if (v.tier == tier) return v;
    }
    throw ArgumentError.value(tier, 'tier', 'No vehicle with this tier');
  }

  RouteSpec routeById(String id) {
    for (final r in routes) {
      if (r.id == id) return r;
    }
    throw ArgumentError.value(id, 'id', 'No route with this id');
  }

  PermitSpec permitById(String id) {
    for (final l in permits) {
      if (l.id == id) return l;
    }
    throw ArgumentError.value(id, 'id', 'No permit with this id');
  }

  CargoSpec cargoByName(String name) {
    for (final c in cargo) {
      if (c.name == name) return c;
    }
    throw ArgumentError.value(name, 'name', 'No cargo with this name');
  }

  /// One-way toll for [tollClass] at [crossing].
  double tollFor(String tollClass, String crossing) {
    final toll = tolls[tollClass]?[crossing];
    if (toll == null) {
      throw ArgumentError('No toll for class "$tollClass" at "$crossing"');
    }
    return toll;
  }

  void _validateCrossReferences() {
    final tiers = <int>{};
    for (final v in vehicles) {
      if (!tiers.add(v.tier)) {
        throw ConfigException('vehicles: duplicate tier ${v.tier}');
      }
      if (!tolls.containsKey(v.tollClass)) {
        throw ConfigException(
          'vehicles: tier ${v.tier} uses toll class "${v.tollClass}" '
          'which is not in the tolls table',
        );
      }
      if (v.maxLoadT < v.legalPayloadT) {
        throw ConfigException(
          'vehicles: tier ${v.tier} maxLoadT is below legalPayloadT',
        );
      }
      if (v.legalPayloadT <= 0) {
        throw ConfigException(
          'vehicles: tier ${v.tier} legalPayloadT must be above 0',
        );
      }
      if (v.speedKmh <= 0) {
        throw ConfigException(
          'vehicles: tier ${v.tier} speedKmh must be above 0',
        );
      }
    }
    for (final c in cargo) {
      if (c.allowedTiers.isEmpty) {
        throw ConfigException('cargo: "${c.name}" allowedTiers is empty');
      }
      for (final tier in c.allowedTiers) {
        if (!tiers.contains(tier)) {
          throw ConfigException(
            'cargo: "${c.name}" allowedTiers lists tier $tier '
            'which is not a vehicle tier',
          );
        }
      }
    }
    final routeIds = <String>{};
    for (final r in routes) {
      if (!routeIds.add(r.id)) {
        throw ConfigException('routes: duplicate id "${r.id}"');
      }
    }
    if (settings.startingGarageSlots < 1) {
      throw const ConfigException(
        'settings.startingGarageSlots must be at least 1',
      );
    }
    if (settings.resaleShareOfPrice < 0 || settings.resaleShareOfPrice > 1) {
      throw ConfigException(
        'settings.resaleShareOfPrice must be between 0 and 1, '
        'got ${settings.resaleShareOfPrice}',
      );
    }
    final permitIds = <String>{};
    for (final l in permits) {
      if (!permitIds.add(l.id)) {
        throw ConfigException('permits: duplicate id "${l.id}"');
      }
      if (l.priceTk <= 0) {
        throw ConfigException('permits: "${l.id}" priceTk must be above 0');
      }
    }
    final starters = vehicles.where(
      (v) => v.tier == settings.starterVehicleTier,
    );
    if (starters.isEmpty) {
      throw ConfigException(
        'settings.starterVehicleTier ${settings.starterVehicleTier} '
        'is not a vehicle tier',
      );
    }
    if (!starters.first.availableAtStart) {
      throw ConfigException(
        'settings.starterVehicleTier ${settings.starterVehicleTier} '
        'needs a permit or deliveries, so it cannot be the free starter',
      );
    }
    final usedPermits = <String>{};
    for (final v in vehicles) {
      final permitId = v.unlockPermitId;
      if (v.unlockDeliveries < 0) {
        throw ConfigException(
          'vehicles: tier ${v.tier} unlockDeliveries cannot be negative',
        );
      }
      if (permitId != null) {
        if (!permitIds.contains(permitId)) {
          throw ConfigException(
            'vehicles: tier ${v.tier} unlockPermit "$permitId" '
            'is not a permit id',
          );
        }
        if (v.unlockDeliveries > 0) {
          throw ConfigException(
            'vehicles: tier ${v.tier} has both a permit and a delivery '
            'count; use one',
          );
        }
        usedPermits.add(permitId);
      }
    }
    for (final id in permitIds.difference(usedPermits)) {
      throw ConfigException('permits: "$id" does not unlock any vehicle');
    }
    for (final v in vehicles) {
      for (final id in v.allowedRoutes) {
        if (!routeIds.contains(id)) {
          throw ConfigException(
            'vehicles: tier ${v.tier} allowedRoutes lists "$id" '
            'which is not a route id',
          );
        }
      }
    }
    for (final r in routes) {
      for (final entry in tolls.entries) {
        if (!entry.value.containsKey(r.crossing)) {
          throw ConfigException(
            'routes: ${r.id} crossing "${r.crossing}" is missing from '
            'tolls["${entry.key}"]',
          );
        }
      }
    }
  }
}

EconomySettings _parseSettings(_Reader r) => EconomySettings(
  dieselPricePerLitre: r.number('dieselPricePerLitre'),
  baseFarePerTon: r.number('baseFarePerTon'),
  ratePerTonKm: r.number('ratePerTonKm'),
  freightMultiplier: r.number('freightMultiplier'),
  gameMinutesPerRealMinute: r.number('gameMinutesPerRealMinute'),
  turboPhase1EndMin: r.integer('turboPhase1EndMin'),
  turboPhase1Speed: r.number('turboPhase1Speed'),
  turboPhase2EndMin: r.integer('turboPhase2EndMin'),
  turboPhase2Speed: r.number('turboPhase2Speed'),
  turboPhase3EndMin: r.integer('turboPhase3EndMin'),
  turboPhase3Speed: r.number('turboPhase3Speed'),
  startingCash: r.integer('startingCash'),
  firstTerminalPrice: r.integer('firstTerminalPrice'),
  extraFuelPerFullOverload: r.number('extraFuelPerFullOverload'),
  extraWearPerFullOverload: r.number('extraWearPerFullOverload'),
  weighbridgeCheckChance: r.number('weighbridgeCheckChance'),
  overloadFineBase: r.number('overloadFineBase'),
  overloadFinePerTon: r.number('overloadFinePerTon'),
  accidentChancePer100Km: r.number('accidentChancePer100Km'),
  accidentGrowthPerFullOverload: r.number('accidentGrowthPerFullOverload'),
  accidentCostShareOfPrice: r.number('accidentCostShareOfPrice'),
  maxLineHaulKm: r.number('maxLineHaulKm'),
  startingGarageSlots: r.integer('startingGarageSlots'),
  resaleShareOfPrice: r.number('resaleShareOfPrice'),
  starterVehicleTier: r.integer('starterVehicleTier'),
);

VehicleSpec _parseVehicle(_Reader r) => VehicleSpec(
  tier: r.integer('tier'),
  name: r.string('name'),
  realWorld: r.string('realWorld'),
  priceTk: r.integer('priceTk'),
  legalPayloadT: r.number('legalPayloadT'),
  maxLoadT: r.number('maxLoadT'),
  speedKmh: r.number('speedKmh'),
  mileageKmPerL: r.number('mileageKmPerL'),
  otherEnergyTkPerKm: r.number('otherEnergyTkPerKm'),
  maintenanceTkPerKm: r.number('maintenanceTkPerKm'),
  crewWageTkPerGameHour: r.number('crewWageTkPerGameHour'),
  loadTimeGameH: r.number('loadTimeGameH'),
  smallLoadPremium: r.number('smallLoadPremium'),
  tollClass: r.string('tollClass'),
  highwayAllowed: r.boolean('highwayAllowed'),
  unlockPermitId: r.optionalString('unlockPermit'),
  unlockDeliveries: r.integer('unlockDeliveries'),
  allowedRoutes: List.unmodifiable(r.stringList('allowedRoutes')),
);

PermitSpec _parsePermit(_Reader r) => PermitSpec(
  id: r.string('id'),
  name: r.string('name'),
  priceTk: r.integer('priceTk'),
);

CargoSpec _parseCargo(_Reader r) => CargoSpec(
  name: r.string('name'),
  rateFactor: r.number('rateFactor'),
  allowedTiers: List.unmodifiable(r.integerList('allowedTiers')),
);

RouteSpec _parseRoute(_Reader r) {
  final haul = r.string('haulType');
  final HaulType haulType;
  switch (haul) {
    case 'local':
      haulType = HaulType.local;
    case 'line':
      haulType = HaulType.line;
    default:
      throw ConfigException(
        '${r.path}.haulType must be "local" or "line", got "$haul"',
      );
  }
  return RouteSpec(
    id: r.string('id'),
    from: r.string('from'),
    to: r.string('to'),
    distanceKm: r.number('distanceKm'),
    haulType: haulType,
    crossing: r.string('crossing'),
    weighbridges: r.integer('weighbridges'),
    extraDelayGameH: r.number('extraDelayGameH'),
    dailyDemandT: r.number('dailyDemandT'),
  );
}

Map<String, Map<String, double>> _parseTolls(_Reader r) {
  final result = <String, Map<String, double>>{};
  for (final tollClass in r.keys) {
    final row = r.object(tollClass);
    result[tollClass] = {for (final c in row.keys) c: row.number(c)};
  }
  return result;
}

/// Reads typed fields from a JSON map and reports the full path on failure.
class _Reader {
  _Reader(this._map, this.path);

  final Map<String, Object?> _map;
  final String path;

  Iterable<String> get keys => _map.keys;

  Object _require(String key) {
    final value = _map[key];
    if (value == null) {
      throw ConfigException('$path.$key is missing');
    }
    return value;
  }

  double number(String key) {
    final value = _require(key);
    if (value is! num) {
      throw ConfigException('$path.$key must be a number, got "$value"');
    }
    return value.toDouble();
  }

  int integer(String key) {
    final value = _require(key);
    if (value is int) return value;
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw ConfigException('$path.$key must be a whole number, got "$value"');
  }

  String string(String key) {
    final value = _require(key);
    if (value is! String) {
      throw ConfigException('$path.$key must be a string, got "$value"');
    }
    return value;
  }

  /// A string, or null when the key is absent or null.
  String? optionalString(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! String) {
      throw ConfigException(
        '$path.$key must be a string or null, got "$value"',
      );
    }
    return value;
  }

  List<int> integerList(String key) {
    final value = _require(key);
    if (value is! List<Object?>) {
      throw ConfigException('$path.$key must be a list');
    }
    final result = <int>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! int) {
        throw ConfigException('$path.$key[$i] must be a whole number');
      }
      result.add(item);
    }
    return result;
  }

  List<String> stringList(String key) {
    final value = _require(key);
    if (value is! List<Object?>) {
      throw ConfigException('$path.$key must be a list');
    }
    final result = <String>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! String) {
        throw ConfigException('$path.$key[$i] must be a string');
      }
      result.add(item);
    }
    return result;
  }

  bool boolean(String key) {
    final value = _require(key);
    if (value is! bool) {
      throw ConfigException('$path.$key must be true or false, got "$value"');
    }
    return value;
  }

  _Reader object(String key) {
    final value = _require(key);
    if (value is! Map<String, Object?>) {
      throw ConfigException('$path.$key must be an object');
    }
    return _Reader(value, '$path.$key');
  }

  List<_Reader> list(String key) {
    final value = _require(key);
    if (value is! List<Object?>) {
      throw ConfigException('$path.$key must be a list');
    }
    final readers = <_Reader>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! Map<String, Object?>) {
        throw ConfigException('$path.$key[$i] must be an object');
      }
      readers.add(_Reader(item, '$path.$key[$i]'));
    }
    return readers;
  }
}
