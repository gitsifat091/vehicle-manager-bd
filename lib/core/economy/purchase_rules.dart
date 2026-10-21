import '../config/economy_config.dart';

enum PurchaseRejectionReason {
  /// Every garage slot is taken by a vehicle the player owns.
  noFreeGarageSlot,
}

/// Why a vehicle cannot be bought. [message] is for logs and tests; the UI
/// maps [reason] to an ARB string.
class PurchaseRejection {
  const PurchaseRejection(this.reason, this.message);

  final PurchaseRejectionReason reason;
  final String message;

  @override
  String toString() => 'PurchaseRejection(${reason.name}): $message';
}

/// Garage slots the player has. Only the starting slots exist for now; terminal
/// and slot expansion come in Milestone 5.
int garageSlots(EconomySettings settings) => settings.startingGarageSlots;

/// Slots not taken by the [vehiclesOwned] vehicles. Never below zero.
int freeGarageSlots({
  required EconomySettings settings,
  required int vehiclesOwned,
}) {
  final free = garageSlots(settings) - vehiclesOwned;
  return free < 0 ? 0 : free;
}

/// Returns why a new vehicle cannot be bought, or null when a slot is free.
/// The free starter Sathi Plus counts as one of [vehiclesOwned].
PurchaseRejection? checkGarageSlot({
  required EconomySettings settings,
  required int vehiclesOwned,
}) {
  if (freeGarageSlots(settings: settings, vehiclesOwned: vehiclesOwned) > 0) {
    return null;
  }
  return PurchaseRejection(
    PurchaseRejectionReason.noFreeGarageSlot,
    'The garage holds ${garageSlots(settings)} vehicles and all slots are '
    'taken ($vehiclesOwned owned).',
  );
}
