import '../config/economy_config.dart';
import 'unlock_rules.dart';

enum PurchaseRejectionReason {
  /// The vehicle is not unlocked yet (a permit or a delivery count). The
  /// rejection's [PurchaseRejection.unlock] says which.
  locked,

  /// Every garage slot is taken by a vehicle the player owns.
  noFreeGarageSlot,

  /// The company's cash is below the vehicle's price.
  notEnoughCash,
}

/// Why a vehicle cannot be bought. [message] is for logs and tests; the UI
/// maps [reason] to an ARB string.
class PurchaseRejection {
  const PurchaseRejection(this.reason, this.message, {this.unlock});

  final PurchaseRejectionReason reason;
  final String message;

  /// Set for [PurchaseRejectionReason.locked]: what unlocks the vehicle.
  final UnlockRejection? unlock;

  @override
  String toString() => 'PurchaseRejection(${reason.name}): $message';
}

enum SaleRejectionReason {
  /// The vehicle has a trip that has not been settled. Unassign it, let the
  /// trip finish, then sell.
  vehicleOnTheRoad,

  /// The vehicle is not in the garage, for example a second tap on a sale
  /// that already went through.
  notOwned,

  /// It is the company's last vehicle and the cash after the sale would not
  /// buy the cheapest vehicle the company can buy, so it would be left with
  /// nothing to earn with.
  lastVehicleUnaffordable,
}

/// Why a vehicle cannot be sold. [message] is for logs and tests.
class SaleRejection {
  const SaleRejection(this.reason, this.message);

  final SaleRejectionReason reason;
  final String message;

  @override
  String toString() => 'SaleRejection(${reason.name}): $message';
}

/// What selling a bought [vehicle] pays, in whole Taka: its price times
/// settings.resaleShareOfPrice, rounded only here.
int resaleValueTk({
  required EconomySettings settings,
  required VehicleSpec vehicle,
}) => (vehicle.priceTk * settings.resaleShareOfPrice).round();

/// What selling an owned vehicle pays: settings.starterSaleValue for the free
/// starter ([isStarter]), [resaleValueTk] for any other.
int saleValueTk({
  required EconomySettings settings,
  required VehicleSpec vehicle,
  required bool isStarter,
}) => isStarter
    ? settings.starterSaleValue
    : resaleValueTk(settings: settings, vehicle: vehicle);

/// The price of the cheapest vehicle the company can buy now (unlocked by
/// [completedTrips] and [ownedPermits]), or null when none is unlocked.
/// Garage slots and cash are not considered.
int? cheapestBuyablePriceTk({
  required EconomyConfig config,
  required int completedTrips,
  required Set<String> ownedPermits,
}) {
  int? cheapest;
  for (final v in config.vehicles) {
    final locked = checkVehicleUnlocked(
      vehicle: v,
      completedTrips: completedTrips,
      ownedPermits: ownedPermits,
    );
    if (locked != null) continue;
    if (cheapest == null || v.priceTk < cheapest) cheapest = v.priceTk;
  }
  return cheapest;
}

/// Returns why a vehicle cannot be sold now, or null when it can.
///
/// [onTheRoad] is true while the vehicle has an unsettled trip.
/// [vehiclesOwned] counts the vehicle being sold. [cashAfterSale] is the cash
/// once the sale is paid, and [cheapestBuyableTk] comes from
/// [cheapestBuyablePriceTk]. Selling the last vehicle is refused unless the
/// cash after the sale buys at least that vehicle (exactly the price is
/// enough), so the company can never be left with nothing to earn with.
SaleRejection? checkSale({
  required bool onTheRoad,
  required int vehiclesOwned,
  required int cashAfterSale,
  required int? cheapestBuyableTk,
}) {
  if (onTheRoad) {
    return const SaleRejection(
      SaleRejectionReason.vehicleOnTheRoad,
      'The vehicle is on the road. Let the trip finish before selling.',
    );
  }
  if (vehiclesOwned <= 1 &&
      (cheapestBuyableTk == null || cashAfterSale < cheapestBuyableTk)) {
    return SaleRejection(
      SaleRejectionReason.lastVehicleUnaffordable,
      'It is the last vehicle, and Tk $cashAfterSale after the sale does not '
      'buy the cheapest vehicle (Tk $cheapestBuyableTk).',
    );
  }
  return null;
}

/// Hours until selling [sold] and buying a better vehicle has paid back what
/// the sale loses, or null when it never does.
///
/// The loss is the part of the sold vehicle's price that the sale does not
/// return: `price - saleValueTk` (for the free starter, [soldIsStarter], its
/// price minus settings.starterSaleValue). The gain is the difference in
/// profit per real hour, [boughtProfitPerHour] minus [soldProfitPerHour]. Both
/// profits are per real hour at 1x (price over payback hours in the economy
/// sheet), so the result is real hours at 1x; Turbo Start makes it pass
/// faster. The price of the new vehicle is not a loss, because it keeps its
/// own resale value.
double? swapPaybackHours({
  required EconomySettings settings,
  required VehicleSpec sold,
  required double soldProfitPerHour,
  required double boughtProfitPerHour,
  bool soldIsStarter = false,
}) {
  final gain = boughtProfitPerHour - soldProfitPerHour;
  if (gain <= 0) return null;
  final loss =
      sold.priceTk -
      saleValueTk(settings: settings, vehicle: sold, isStarter: soldIsStarter);
  return loss / gain;
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

/// Returns why [vehicle] cannot be bought now, or null when it can.
///
/// Checked in the order the buy screen explains them: a locked vehicle first
/// (saving up does not help), then a full garage, then cash.
PurchaseRejection? checkVehiclePurchase({
  required EconomySettings settings,
  required VehicleSpec vehicle,
  required int cash,
  required int vehiclesOwned,
  required int completedTrips,
  required Set<String> ownedPermits,
}) {
  final unlock = checkVehicleUnlocked(
    vehicle: vehicle,
    completedTrips: completedTrips,
    ownedPermits: ownedPermits,
  );
  if (unlock != null) {
    return PurchaseRejection(
      PurchaseRejectionReason.locked,
      unlock.message,
      unlock: unlock,
    );
  }
  final slot = checkGarageSlot(
    settings: settings,
    vehiclesOwned: vehiclesOwned,
  );
  if (slot != null) return slot;
  if (cash < vehicle.priceTk) {
    return PurchaseRejection(
      PurchaseRejectionReason.notEnoughCash,
      '${vehicle.name} (tier ${vehicle.tier}) costs Tk ${vehicle.priceTk}, '
      'cash is Tk $cash.',
    );
  }
  return null;
}
