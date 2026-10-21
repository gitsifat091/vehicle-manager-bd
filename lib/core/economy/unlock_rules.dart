import '../config/economy_config.dart';

enum UnlockRejectionReason {
  /// The company has not settled enough trips yet (tier 3: 5 deliveries).
  needsDeliveries,

  /// The vehicle needs a license the player does not own.
  needsLicense,
}

/// Why a vehicle cannot be bought yet. [message] is for logs and tests; the UI
/// maps [reason] to an ARB string and uses [deliveriesNeeded] or [licenseId].
class UnlockRejection {
  const UnlockRejection(
    this.reason,
    this.message, {
    this.deliveriesNeeded,
    this.licenseId,
  });

  final UnlockRejectionReason reason;
  final String message;

  /// Set for [UnlockRejectionReason.needsDeliveries].
  final int? deliveriesNeeded;

  /// Set for [UnlockRejectionReason.needsLicense].
  final String? licenseId;

  @override
  String toString() => 'UnlockRejection(${reason.name}): $message';
}

/// Returns why [vehicle] cannot be bought yet, or null when it is unlocked.
///
/// [completedTrips] is `Company.completedTrips`. [ownedLicenses] holds the ids
/// of the licenses the player has bought. A vehicle needs either a license or
/// a delivery count, never both (the config checks that).
UnlockRejection? checkVehicleUnlocked({
  required VehicleSpec vehicle,
  required int completedTrips,
  required Set<String> ownedLicenses,
}) {
  final licenseId = vehicle.unlockLicenseId;
  if (licenseId != null && !ownedLicenses.contains(licenseId)) {
    return UnlockRejection(
      UnlockRejectionReason.needsLicense,
      '${vehicle.name} (tier ${vehicle.tier}) needs the "$licenseId" license.',
      licenseId: licenseId,
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

/// The vehicles that need [licenseId], in tier order.
List<VehicleSpec> vehiclesUnlockedBy(EconomyConfig config, String licenseId) {
  return [
    for (final v in config.vehicles)
      if (v.unlockLicenseId == licenseId) v,
  ];
}

enum LicenseRejectionReason { alreadyOwned, notEnoughCash }

/// Why a license cannot be bought. [message] is for logs and tests.
class LicenseRejection {
  const LicenseRejection(this.reason, this.message);

  final LicenseRejectionReason reason;
  final String message;

  @override
  String toString() => 'LicenseRejection(${reason.name}): $message';
}

/// Returns why [license] cannot be bought now, or null when it can. A license
/// is a one-time purchase in Taka: the price is paid once and never again.
LicenseRejection? checkLicensePurchase({
  required LicenseSpec license,
  required int cash,
  required Set<String> ownedLicenses,
}) {
  if (ownedLicenses.contains(license.id)) {
    return LicenseRejection(
      LicenseRejectionReason.alreadyOwned,
      'The "${license.id}" license is already owned.',
    );
  }
  if (cash < license.priceTk) {
    return LicenseRejection(
      LicenseRejectionReason.notEnoughCash,
      'The "${license.id}" license costs Tk ${license.priceTk}, '
      'cash is Tk $cash.',
    );
  }
  return null;
}
