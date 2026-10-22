import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/purchase_rules.dart';
import 'package:vehicle_manager_bd/core/economy/trip_planner.dart';

import '../../support/sim_support.dart';
import '../test_config.dart';

void main() {
  final settings = loadDefaultConfig().settings;

  test('the garage starts with 6 slots', () {
    expect(settings.startingGarageSlots, 6);
    expect(garageSlots(settings), 6);
  });

  test('the free starter Sathi Plus takes the first slot', () {
    expect(freeGarageSlots(settings: settings, vehiclesOwned: 1), 5);
  });

  test('a purchase is allowed while a slot is free', () {
    for (var owned = 0; owned < 6; owned++) {
      expect(
        checkGarageSlot(settings: settings, vehiclesOwned: owned),
        isNull,
        reason: '$owned owned',
      );
    }
  });

  test('a purchase with no free slot is rejected with its own reason', () {
    final rejection = checkGarageSlot(settings: settings, vehiclesOwned: 6);
    expect(rejection!.reason, PurchaseRejectionReason.noFreeGarageSlot);
    expect(rejection.message, contains('6'));
    expect(
      checkGarageSlot(settings: settings, vehiclesOwned: 9)?.reason,
      PurchaseRejectionReason.noFreeGarageSlot,
    );
  });

  test('free slots never go below zero', () {
    expect(freeGarageSlots(settings: settings, vehiclesOwned: 9), 0);
  });

  group('selling', () {
    final config = loadDefaultConfig();

    test('a vehicle sells for its price times the resale share', () {
      expect(settings.resaleShareOfPrice, 0.6);
      expect(
        resaleValueTk(settings: settings, vehicle: config.vehicleByTier(4)),
        780000,
      );
      expect(
        resaleValueTk(settings: settings, vehicle: config.vehicleByTier(1)),
        12000,
      );
    });

    test('the sale value is rounded to whole Taka', () {
      final odd = editedConfig(
        (j) => j['settings']['resaleShareOfPrice'] = 0.333,
      );
      expect(
        resaleValueTk(settings: odd.settings, vehicle: odd.vehicleByTier(1)),
        6660,
      );
    });

    test('selling and buying straight back always loses money', () {
      for (final v in config.vehicles) {
        expect(
          resaleValueTk(settings: settings, vehicle: v),
          lessThan(v.priceTk),
          reason: 'tier ${v.tier}',
        );
      }
    });

    test('a vehicle on the road cannot be sold', () {
      expect(
        checkSale(onTheRoad: true)?.reason,
        SaleRejectionReason.vehicleOnTheRoad,
      );
      expect(checkSale(onTheRoad: false), isNull);
    });
  });

  group('swap payback', () {
    final config = loadDefaultConfig();
    final bijli = config.vehicleByTier(2);
    final sonar = config.vehicleByTier(1);

    test('hours = resale loss / profit gain per hour', () {
      // Bijli Cargo: price 150,000, resale 90,000, loss 60,000.
      // Gain 10,000 - 4,000 = 6,000 per hour, so 10 hours.
      expect(
        swapPaybackHours(
          settings: settings,
          sold: bijli,
          soldProfitPerHour: 4000,
          boughtProfitPerHour: 10000,
        ),
        closeTo(10, 1e-9),
      );
    });

    test('a bigger gain earns the loss back sooner', () {
      double? hours(double bought) => swapPaybackHours(
        settings: settings,
        sold: bijli,
        soldProfitPerHour: 4000,
        boughtProfitPerHour: bought,
      );
      expect(hours(10000)!, greaterThan(hours(20000)!));
      expect(hours(20000)!, closeTo(60000 / 16000, 1e-9));
    });

    test('never, when the new vehicle earns the same or less', () {
      for (final bought in [4000.0, 3999.0, 0.0, -50.0]) {
        expect(
          swapPaybackHours(
            settings: settings,
            sold: bijli,
            soldProfitPerHour: 4000,
            boughtProfitPerHour: bought,
          ),
          isNull,
          reason: 'bought $bought',
        );
      }
    });

    test('a vehicle that loses money is easy to replace', () {
      // Gain 5,000 - (-1,000) = 6,000; loss 8,000 on a Sonar Van.
      expect(
        swapPaybackHours(
          settings: settings,
          sold: sonar,
          soldProfitPerHour: -1000,
          boughtProfitPerHour: 5000,
        ),
        closeTo(8000 / 6000, 1e-9),
      );
    });

    test('the loss follows the resale share', () {
      double hours(double share) => swapPaybackHours(
        settings: editedConfig(
          (j) => j['settings']['resaleShareOfPrice'] = share,
        ).settings,
        sold: bijli,
        soldProfitPerHour: 0,
        boughtProfitPerHour: 15000,
      )!;
      expect(hours(0.5), closeTo(75000 / 15000, 1e-9));
      expect(hours(0.6), closeTo(60000 / 15000, 1e-9));
      expect(hours(0.9), closeTo(15000 / 15000, 1e-9));
      expect(hours(1), 0);
    });

    test('works with real quotes: Bijli Cargo to Tuntuni Mini on R01', () {
      double perHour(int tier) {
        final vehicle = config.vehicleByTier(tier);
        final q = quoteTrip(
          config: config,
          vehicle: vehicle,
          route: config.routeById('R01'),
          cargo: config.cargoByName('Parcels'),
        );
        return q.profit /
            (q.tripGameHours / config.settings.gameMinutesPerRealMinute);
      }

      final bijliHour = perHour(2);
      final miniHour = perHour(3);
      expect(bijliHour, closeTo(31529, 1));
      expect(miniHour, closeTo(74898, 1));
      final hours = swapPaybackHours(
        settings: settings,
        sold: bijli,
        soldProfitPerHour: bijliHour,
        boughtProfitPerHour: miniHour,
      );
      // Loss 60,000 over a gain of about 43,369 per hour.
      expect(hours, closeTo(60000 / (miniHour - bijliHour), 1e-9));
      expect(hours, closeTo(1.38, 0.01));
    });
  });

  test('the slot count follows the config', () {
    final bigger = editedConfig(
      (j) => j['settings']['startingGarageSlots'] = 10,
    ).settings;
    expect(checkGarageSlot(settings: bigger, vehiclesOwned: 6), isNull);
    expect(freeGarageSlots(settings: bigger, vehiclesOwned: 6), 4);
  });

  group('checkVehiclePurchase', () {
    final config = loadDefaultConfig();

    PurchaseRejection? check(
      int tier, {
      int cash = 100000000,
      int owned = 1,
      int trips = 0,
      Set<String> permits = const {},
    }) => checkVehiclePurchase(
      settings: config.settings,
      vehicle: config.vehicleByTier(tier),
      cash: cash,
      vehiclesOwned: owned,
      completedTrips: trips,
      ownedPermits: permits,
    );

    test('an open vehicle with a free slot and enough cash can be bought', () {
      expect(check(4), isNull);
      expect(check(2, cash: 150000), isNull, reason: 'exactly the price');
    });

    test('short of cash by one Taka is refused', () {
      final r = check(2, cash: 149999)!;
      expect(r.reason, PurchaseRejectionReason.notEnoughCash);
      expect(r.unlock, isNull);
    });

    test('a full garage is refused', () {
      expect(
        check(4, owned: 6)!.reason,
        PurchaseRejectionReason.noFreeGarageSlot,
      );
    });

    test('a vehicle that needs deliveries is locked until they are done', () {
      final r = check(3, trips: 4)!;
      expect(r.reason, PurchaseRejectionReason.locked);
      expect(r.unlock!.deliveriesNeeded, 5);
      expect(check(3, trips: 5), isNull);
    });

    test('a vehicle that needs a permit is locked until it is owned', () {
      final r = check(5)!;
      expect(r.reason, PurchaseRejectionReason.locked);
      expect(r.unlock!.permitId, 'light');
      expect(check(5, permits: {'light'}), isNull);
    });

    test('locked comes before a full garage, which comes before cash', () {
      expect(
        check(5, cash: 0, owned: 6)!.reason,
        PurchaseRejectionReason.locked,
      );
      expect(
        check(4, cash: 0, owned: 6)!.reason,
        PurchaseRejectionReason.noFreeGarageSlot,
      );
    });
  });
}
