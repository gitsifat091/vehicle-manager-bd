import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/purchase_rules.dart';

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

  test('the slot count follows the config', () {
    final bigger = editedConfig(
      (j) => j['settings']['startingGarageSlots'] = 10,
    ).settings;
    expect(checkGarageSlot(settings: bigger, vehiclesOwned: 6), isNull);
    expect(freeGarageSlots(settings: bigger, vehiclesOwned: 6), 4);
  });
}
