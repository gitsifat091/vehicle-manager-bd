import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/config/economy_config.dart';

import '../test_config.dart';

/// Decodes the real economy.json, lets [edit] change it, and re-encodes.
String edited(void Function(Map<String, dynamic> json) edit) {
  final json = jsonDecode(readEconomyJson()) as Map<String, dynamic>;
  edit(json);
  return jsonEncode(json);
}

Matcher configError(String fragment) => throwsA(
  isA<ConfigException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  group('EconomyConfig.parse', () {
    final config = loadDefaultConfig();

    test('reads the real economy.json', () {
      expect(config.currency, 'BDT');
      expect(config.vehicles, hasLength(12));
      expect(config.cargo, hasLength(12));
      expect(config.routes, hasLength(16));
      expect(config.tolls, hasLength(7));
      expect(config.settings.dieselPricePerLitre, 135);
      expect(config.settings.startingCash, 1500000);
      expect(config.settings.maxLineHaulKm, 400);
    });

    test('looks things up by tier, id and name', () {
      expect(config.vehicleByTier(6).name, 'Jamuna Open');
      expect(config.routeById('R05').distanceKm, 250);
      expect(config.routeById('R01').haulType, HaulType.local);
      expect(config.cargoByName('Rice').rateFactor, 1);
      expect(config.tollFor('Medium truck', 'Meghna+Gumti'), 800);
    });

    test('unknown lookups throw ArgumentError', () {
      expect(() => config.vehicleByTier(99), throwsArgumentError);
      expect(() => config.routeById('R99'), throwsArgumentError);
      expect(() => config.cargoByName('Gold'), throwsArgumentError);
      expect(() => config.tollFor('Medium truck', 'Moon'), throwsArgumentError);
    });

    test('lists and maps are unmodifiable', () {
      expect(() => config.vehicles.removeLast(), throwsUnsupportedError);
      expect(() => config.tolls['Light']!['None'] = 1, throwsUnsupportedError);
    });

    test('rejects text that is not JSON', () {
      expect(() => EconomyConfig.parse('not json'), configError('not valid'));
    });

    test('names a missing settings field', () {
      final text = edited((j) => j['settings'].remove('dieselPricePerLitre'));
      expect(
        () => EconomyConfig.parse(text),
        configError('economy.json.settings.dieselPricePerLitre is missing'),
      );
    });

    test('names a missing vehicle field with its list index', () {
      final text = edited((j) => j['vehicles'][3].remove('speedKmh'));
      expect(
        () => EconomyConfig.parse(text),
        configError('economy.json.vehicles[3].speedKmh is missing'),
      );
    });

    test('rejects a wrong type', () {
      final text = edited((j) => j['routes'][0]['distanceKm'] = 'far');
      expect(
        () => EconomyConfig.parse(text),
        configError('routes[0].distanceKm must be a number'),
      );
    });

    test('rejects a missing top-level section', () {
      final text = edited((j) => j.remove('tolls'));
      expect(
        () => EconomyConfig.parse(text),
        configError('economy.json.tolls is missing'),
      );
    });

    test('rejects an unknown haul type', () {
      final text = edited((j) => j['routes'][0]['haulType'] = 'air');
      expect(() => EconomyConfig.parse(text), configError('haulType'));
    });

    test('rejects a vehicle with an unknown toll class', () {
      final text = edited((j) => j['vehicles'][0]['tollClass'] = 'Rocket');
      expect(() => EconomyConfig.parse(text), configError('Rocket'));
    });

    test('rejects a route crossing missing from the toll table', () {
      final text = edited((j) => j['routes'][0]['crossing'] = 'Atlantis');
      expect(() => EconomyConfig.parse(text), configError('Atlantis'));
    });

    test('reads cargo allowedTiers', () {
      expect(config.cargoByName('Fuel').allowedTiers, [10]);
      expect(config.cargoByName('Containers').allowedTiers, [11]);
    });

    test('rejects a cargo tier that is not a vehicle tier', () {
      final text = edited((j) => j['cargo'][0]['allowedTiers'] = [1, 99]);
      expect(() => EconomyConfig.parse(text), configError('tier 99'));
    });

    test('rejects missing or empty allowedTiers', () {
      final missing = edited((j) => j['cargo'][0].remove('allowedTiers'));
      expect(
        () => EconomyConfig.parse(missing),
        configError('cargo[0].allowedTiers is missing'),
      );
      final empty = edited((j) => j['cargo'][0]['allowedTiers'] = []);
      expect(() => EconomyConfig.parse(empty), configError('is empty'));
    });

    test('reads the permits table', () {
      expect(config.permits.map((l) => l.id), [
        'light',
        'medium',
        'coldchain',
        'hazmat',
        'heavy',
      ]);
      expect(config.permitById('hazmat').name, 'Hazmat operating permit');
      expect(config.permitById('heavy').priceTk, 1000000);
      expect(() => config.permitById('pilot'), throwsArgumentError);
      expect(() => config.permits.removeLast(), throwsUnsupportedError);
    });

    test('reads vehicle unlocks: a permit id or a delivery count', () {
      expect(config.vehicleByTier(3).unlockDeliveries, 5);
      expect(config.vehicleByTier(3).unlockPermitId, isNull);
      expect(config.vehicleByTier(5).unlockPermitId, 'light');
      expect(config.vehicleByTier(5).unlockDeliveries, 0);
      for (final v in config.vehicles) {
        expect(
          v.unlockPermitId != null && v.unlockDeliveries > 0,
          false,
          reason: 'tier ${v.tier} has both',
        );
      }
    });

    test('rejects an unlock permit that is not in the table', () {
      final text = edited((j) => j['vehicles'][4]['unlockPermit'] = 'pilot');
      expect(() => EconomyConfig.parse(text), configError('"pilot"'));
    });

    test('rejects a vehicle with both a permit and a delivery count', () {
      final text = edited((j) => j['vehicles'][4]['unlockDeliveries'] = 3);
      expect(() => EconomyConfig.parse(text), configError('use one'));
    });

    test('rejects a missing delivery count and a negative one', () {
      final missing = edited(
        (j) => j['vehicles'][0].remove('unlockDeliveries'),
      );
      expect(
        () => EconomyConfig.parse(missing),
        configError('vehicles[0].unlockDeliveries is missing'),
      );
      final negative = edited((j) => j['vehicles'][0]['unlockDeliveries'] = -1);
      expect(() => EconomyConfig.parse(negative), configError('negative'));
    });

    test('rejects a permit that unlocks nothing', () {
      final text = edited((j) {
        for (final v in j['vehicles']) {
          if (v['unlockPermit'] == 'light') v['unlockPermit'] = null;
        }
      });
      expect(
        () => EconomyConfig.parse(text),
        configError('"light" does not unlock any vehicle'),
      );
    });

    test('rejects duplicate permit ids and a zero price', () {
      final dup = edited((j) => j['permits'][1]['id'] = 'light');
      expect(() => EconomyConfig.parse(dup), configError('duplicate id'));
      final free = edited((j) => j['permits'][0]['priceTk'] = 0);
      expect(() => EconomyConfig.parse(free), configError('priceTk must be'));
    });

    test('reads vehicle allowedRoutes: only tier 1 is limited', () {
      expect(config.vehicleByTier(1).allowedRoutes, ['M01', 'M02']);
      expect(config.vehicleByTier(1).canRunRoute('M02'), true);
      expect(config.vehicleByTier(1).canRunRoute('R01'), false);
      for (final v in config.vehicles.where((v) => v.tier != 1)) {
        expect(v.allowedRoutes, isEmpty, reason: 'tier ${v.tier}');
      }
    });

    test('rejects an allowedRoutes entry that is not a route id', () {
      final text = edited(
        (j) => j['vehicles'][0]['allowedRoutes'] = ['M01', 'X99'],
      );
      expect(() => EconomyConfig.parse(text), configError('"X99"'));
    });

    test('rejects missing or non-string allowedRoutes', () {
      final missing = edited((j) => j['vehicles'][0].remove('allowedRoutes'));
      expect(
        () => EconomyConfig.parse(missing),
        configError('vehicles[0].allowedRoutes is missing'),
      );
      final wrong = edited((j) => j['vehicles'][0]['allowedRoutes'] = [1]);
      expect(
        () => EconomyConfig.parse(wrong),
        configError('allowedRoutes[0] must be a string'),
      );
    });

    test('reads startingGarageSlots and rejects a missing or zero value', () {
      expect(config.settings.startingGarageSlots, 6);
      final missing = edited(
        (j) => j['settings'].remove('startingGarageSlots'),
      );
      expect(
        () => EconomyConfig.parse(missing),
        configError('settings.startingGarageSlots is missing'),
      );
      final zero = edited((j) => j['settings']['startingGarageSlots'] = 0);
      expect(
        () => EconomyConfig.parse(zero),
        configError('startingGarageSlots must be at least 1'),
      );
    });

    test('reads resaleShareOfPrice and keeps it between 0 and 1', () {
      expect(config.settings.resaleShareOfPrice, 0.6);
      final missing = edited((j) => j['settings'].remove('resaleShareOfPrice'));
      expect(
        () => EconomyConfig.parse(missing),
        configError('settings.resaleShareOfPrice is missing'),
      );
      for (final bad in [-0.1, 1.5]) {
        final text = edited((j) => j['settings']['resaleShareOfPrice'] = bad);
        expect(
          () => EconomyConfig.parse(text),
          configError('resaleShareOfPrice must be between 0 and 1'),
        );
      }
    });

    test('reads starterVehicleTier and checks it is an open tier', () {
      expect(config.settings.starterVehicleTier, 4);
      expect(config.vehicleByTier(4).availableAtStart, true);

      final missing = edited((j) => j['settings'].remove('starterVehicleTier'));
      expect(
        () => EconomyConfig.parse(missing),
        configError('settings.starterVehicleTier is missing'),
      );
      final unknown = edited((j) => j['settings']['starterVehicleTier'] = 99);
      expect(
        () => EconomyConfig.parse(unknown),
        configError('is not a vehicle tier'),
      );
      // Tier 3 needs 5 deliveries and tier 5 a permit: not a free starter.
      for (final locked in [3, 5]) {
        final text = edited(
          (j) => j['settings']['starterVehicleTier'] = locked,
        );
        expect(
          () => EconomyConfig.parse(text),
          configError('cannot be the free starter'),
          reason: 'tier $locked',
        );
      }
    });

    test('rejects missing maxLineHaulKm', () {
      final text = edited((j) => j['settings'].remove('maxLineHaulKm'));
      expect(
        () => EconomyConfig.parse(text),
        configError('settings.maxLineHaulKm is missing'),
      );
    });

    test('rejects duplicate tiers and route ids', () {
      final dupTier = edited((j) => j['vehicles'][1]['tier'] = 1);
      expect(() => EconomyConfig.parse(dupTier), configError('duplicate tier'));
      final dupRoute = edited((j) => j['routes'][1]['id'] = 'M01');
      expect(() => EconomyConfig.parse(dupRoute), configError('duplicate id'));
    });
  });
}
