import '../config/economy_config.dart';

enum UnlockRejectionReason {
  /// The company has not settled enough trips yet (tier 3: 5 deliveries).
  needsDeliveries,

  /// The vehicle needs a permit the player does not own.
  needsPermit,
}

/// Why a vehicle cannot be bought yet. [message] is for logs and tests; the UI
/// maps [reason] to an ARB string and uses [deliveriesNeeded] or [permitId].
class UnlockRejection {
  const UnlockRejection(
    this.reason,
    this.message, {
    this.deliveriesNeeded,
    this.permitId,
  });

  final UnlockRejectionReason reason;
  final String message;

  /// Set for [UnlockRejectionReason.needsDeliveries].
  final int? deliveriesNeeded;

  /// Set for [UnlockRejectionReason.needsPermit].
  final String? permitId;

  @override
  String toString() => 'UnlockRejection(${reason.name}): $message';
}

/// Returns why [vehicle] cannot be bought yet, or null when it is unlocked.
///
/// [completedTrips] is `Company.completedTrips`. [ownedPermits] holds the ids
/// of the permits the player has bought. A vehicle needs either a permit or
/// a delivery count, never both (the config checks that).
UnlockRejection? checkVehicleUnlocked({
  required VehicleSpec vehicle,
  required int completedTrips,
  required Set<String> ownedPermits,
}) {
  final permitId = vehicle.unlockPermitId;
  if (permitId != null && !ownedPermits.contains(permitId)) {
    return UnlockRejection(
      UnlockRejectionReason.needsPermit,
      '${vehicle.name} (tier ${vehicle.tier}) needs the "$permitId" permit.',
      permitId: permitId,
    );
  }
  if (completedTrips < vehicle.unlockDeliveries) {
    return UnlockRejection(
      UnlockRejectionReason.needsDeliveries,
      '${vehicle.name} (tier ${vehicle.tier}) needs ${vehicle.unlockDeliveries} '
      'deliveries ($completedTrips done).',
      deliveriesNeeded: vehicle.unlockDeliveries,
    );
  }
  return null;
}

/// The vehicles that need [permitId], in tier order.
List<VehicleSpec> vehiclesUnlockedBy(EconomyConfig config, String permitId) {
  return [
    for (final v in config.vehicles)
      if (v.unlockPermitId == permitId) v,
  ];
}

enum PermitRejectionReason { alreadyOwned, notEnoughCash }

/// Why a permit cannot be bought. [message] is for logs and tests.
class PermitRejection {
  const PermitRejection(this.reason, this.message);

  final PermitRejectionReason reason;
  final String message;

  @override
  String toString() => 'PermitRejection(${reason.name}): $message';
}

/// Returns why [permit] cannot be bought now, or null when it can. A permit
/// is a one-time purchase in Taka: the price is paid once and never again.
PermitRejection? checkPermitPurchase({
  required PermitSpec permit,
  required int cash,
  required Set<String> ownedPermits,
}) {
  if (ownedPermits.contains(permit.id)) {
    return PermitRejection(
      PermitRejectionReason.alreadyOwned,
      'The "${permit.id}" permit is already owned.',
    );
  }
  if (cash < permit.priceTk) {
    return PermitRejection(
      PermitRejectionReason.notEnoughCash,
      'The "${permit.id}" permit costs Tk ${permit.priceTk}, '
      'cash is Tk $cash.',
    );
  }
  return null;
}
