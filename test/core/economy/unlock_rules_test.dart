import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/unlock_rules.dart';

import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();

  UnlockRejection? check(
    int tier, {
    int trips = 0,
    Set<String> permits = const {},
  }) => checkVehicleUnlocked(
    vehicle: config.vehicleByTier(tier),
    completedTrips: trips,
    ownedPermits: permits,
  );

  group('what is available at the start', () {
    test('tiers 1, 2 and 4 need nothing', () {
      for (final tier in [1, 2, 4]) {
        expect(config.vehicleByTier(tier).availableAtStart, true);
        expect(check(tier), isNull, reason: 'tier $tier');
      }
    });

    test('every other tier is locked at the start', () {
      for (final v in config.vehicles.where(
        (v) => ![1, 2, 4].contains(v.tier),
      )) {
        expect(v.availableAtStart, false, reason: 'tier ${v.tier}');
        expect(check(v.tier), isNotNull, reason: 'tier ${v.tier}');
      }
    });
  });

  group('deliveries', () {
    test('tier 3 needs 5 deliveries', () {
      final vehicle = config.vehicleByTier(3);
      expect(vehicle.unlockDeliveries, 5);
      expect(vehicle.unlockPermitId, isNull);
    });

    test('tier 3 is rejected below 5 settled trips, with the count', () {
      for (final trips in [0, 4]) {
        final r = check(3, trips: trips);
        expect(r!.reason, UnlockRejectionReason.needsDeliveries);
        expect(r.deliveriesNeeded, 5);
        expect(r.permitId, isNull);
      }
    });

    test('tier 3 opens at exactly 5 settled trips', () {
      expect(check(3, trips: 5), isNull);
      expect(check(3, trips: 500), isNull);
    });
  });

  group('permits', () {
    const expected = {
      5: 'light',
      6: 'medium',
      7: 'medium',
      8: 'coldchain',
      9: 'heavy',
      10: 'hazmat',
      11: 'heavy',
      12: 'heavy',
    };

    test('each tier needs the permit the design names', () {
      for (final e in expected.entries) {
        expect(
          config.vehicleByTier(e.key).unlockPermitId,
          e.value,
          reason: 'tier ${e.key}',
        );
      }
    });

    test('a locked tier is rejected with the permit id', () {
      for (final e in expected.entries) {
        final r = check(e.key, trips: 1000);
        expect(r!.reason, UnlockRejectionReason.needsPermit);
        expect(r.permitId, e.value);
      }
    });

    test('owning the permit opens exactly its tiers', () {
      expect(check(5, permits: {'light'}), isNull);
      expect(check(6, permits: {'medium'}), isNull);
      expect(check(7, permits: {'medium'}), isNull);
      expect(check(5, permits: {'medium'}), isNotNull);
      expect(check(6, permits: {'light'}), isNotNull);
      for (final tier in [9, 11, 12]) {
        expect(check(tier, permits: {'heavy'}), isNull, reason: '$tier');
      }
      expect(check(8, permits: {'coldchain'}), isNull);
      expect(check(10, permits: {'hazmat'}), isNull);
      expect(check(10, permits: {'heavy'}), isNotNull);
    });

    test('a permit does not depend on deliveries', () {
      expect(check(5, trips: 0, permits: {'light'}), isNull);
    });

    test('vehiclesUnlockedBy lists the tiers in order', () {
      List<int> tiers(String id) =>
          vehiclesUnlockedBy(config, id).map((v) => v.tier).toList();
      expect(tiers('light'), [5]);
      expect(tiers('medium'), [6, 7]);
      expect(tiers('coldchain'), [8]);
      expect(tiers('hazmat'), [10]);
      expect(tiers('heavy'), [9, 11, 12]);
    });
  });

  group('buying a permit', () {
    final light = config.permitById('light');

    test('prices are one-time amounts in Taka from the config', () {
      expect(light.priceTk, 400000);
      expect(config.permitById('medium').priceTk, 500000);
      expect(config.permitById('coldchain').priceTk, 700000);
      expect(config.permitById('hazmat').priceTk, 800000);
      expect(config.permitById('heavy').priceTk, 1000000);
    });

    test('allowed with enough cash', () {
      expect(
        checkPermitPurchase(
          permit: light,
          cash: 400000,
          ownedPermits: const {},
        ),
        isNull,
      );
    });

    test('rejected without enough cash', () {
      final r = checkPermitPurchase(
        permit: light,
        cash: 399999,
        ownedPermits: const {},
      );
      expect(r!.reason, PermitRejectionReason.notEnoughCash);
    });

    test('rejected when already owned, so it is never paid twice', () {
      final r = checkPermitPurchase(
        permit: light,
        cash: 99999999,
        ownedPermits: const {'light'},
      );
      expect(r!.reason, PermitRejectionReason.alreadyOwned);
    });
  });
}
