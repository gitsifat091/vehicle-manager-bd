import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/unlock_rules.dart';

import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();

  UnlockRejection? check(
    int tier, {
    int trips = 0,
    Set<String> licenses = const {},
  }) => checkVehicleUnlocked(
    vehicle: config.vehicleByTier(tier),
    completedTrips: trips,
    ownedLicenses: licenses,
  );

  group('what is available at the start', () {
    test('tiers 1, 2 and 4 need nothing', () {
      for (final tier in [1, 2, 4]) {
        expect(config.vehicleByTier(tier).availableAtStart, true);
        expect(check(tier), isNull, reason: 'tier $tier');
      }
    });

    test('every other tier is locked at the start', () {
      for (final v in config.vehicles.where((v) => ![1, 2, 4].contains(v.tier))) {
        expect(v.availableAtStart, false, reason: 'tier ${v.tier}');
        expect(check(v.tier), isNotNull, reason: 'tier ${v.tier}');
      }
    });
  });

  group('deliveries', () {
    test('tier 3 needs 5 deliveries', () {
      final vehicle = config.vehicleByTier(3);
      expect(vehicle.unlockDeliveries, 5);
      expect(vehicle.unlockLicenseId, isNull);
    });

    test('tier 3 is rejected below 5 settled trips, with the count', () {
      for (final trips in [0, 4]) {
        final r = check(3, trips: trips);
        expect(r!.reason, UnlockRejectionReason.needsDeliveries);
        expect(r.deliveriesNeeded, 5);
        expect(r.licenseId, isNull);
      }
    });

    test('tier 3 opens at exactly 5 settled trips', () {
      expect(check(3, trips: 5), isNull);
      expect(check(3, trips: 500), isNull);
    });
  });

  group('licenses', () {
    const expected = {
      5: 'light',
      6: 'medium',
      7: 'medium',
      8: 'cold_chain',
      9: 'heavy',
      10: 'hazmat',
      11: 'heavy',
      12: 'heavy',
    };

    test('each tier needs the license the design names', () {
      for (final e in expected.entries) {
        expect(
          config.vehicleByTier(e.key).unlockLicenseId,
          e.value,
          reason: 'tier ${e.key}',
        );
      }
    });

    test('a locked tier is rejected with the license id', () {
      for (final e in expected.entries) {
        final r = check(e.key, trips: 1000);
        expect(r!.reason, UnlockRejectionReason.needsLicense);
        expect(r.licenseId, e.value);
      }
    });

    test('owning the license opens exactly its tiers', () {
      expect(check(5, licenses: {'light'}), isNull);
      expect(check(6, licenses: {'medium'}), isNull);
      expect(check(7, licenses: {'medium'}), isNull);
      expect(check(5, licenses: {'medium'}), isNotNull);
      expect(check(6, licenses: {'light'}), isNotNull);
      for (final tier in [9, 11, 12]) {
        expect(check(tier, licenses: {'heavy'}), isNull, reason: '$tier');
      }
      expect(check(8, licenses: {'cold_chain'}), isNull);
      expect(check(10, licenses: {'hazmat'}), isNull);
      expect(check(10, licenses: {'heavy'}), isNotNull);
    });

    test('a license does not depend on deliveries', () {
      expect(check(5, trips: 0, licenses: {'light'}), isNull);
    });

    test('vehiclesUnlockedBy lists the tiers in order', () {
      List<int> tiers(String id) =>
          vehiclesUnlockedBy(config, id).map((v) => v.tier).toList();
      expect(tiers('light'), [5]);
      expect(tiers('medium'), [6, 7]);
      expect(tiers('cold_chain'), [8]);
      expect(tiers('hazmat'), [10]);
      expect(tiers('heavy'), [9, 11, 12]);
    });
  });

  group('buying a license', () {
    final light = config.licenseById('light');

    test('prices are one-time amounts in Taka from the config', () {
      expect(light.priceTk, 400000);
      expect(config.licenseById('medium').priceTk, 500000);
      expect(config.licenseById('cold_chain').priceTk, 700000);
      expect(config.licenseById('hazmat').priceTk, 800000);
      expect(config.licenseById('heavy').priceTk, 1000000);
    });

    test('allowed with enough cash', () {
      expect(
        checkLicensePurchase(
          license: light,
          cash: 400000,
          ownedLicenses: const {},
        ),
        isNull,
      );
    });

    test('rejected without enough cash', () {
      final r = checkLicensePurchase(
        license: light,
        cash: 399999,
        ownedLicenses: const {},
      );
      expect(r!.reason, LicenseRejectionReason.notEnoughCash);
    });

    test('rejected when already owned, so it is never paid twice', () {
      final r = checkLicensePurchase(
        license: light,
        cash: 99999999,
        ownedLicenses: const {'light'},
      );
      expect(r!.reason, LicenseRejectionReason.alreadyOwned);
    });
  });
}
