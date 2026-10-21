/// The expected result of one trip. Money fields are unrounded expected values
/// in Taka; use the `...Tk` getters when storing or displaying.
class TripQuote {
  const TripQuote({
    required this.vehicleTier,
    required this.routeId,
    required this.cargoName,
    required this.loadT,
    required this.tonsOver,
    required this.overloadRatio,
    required this.drivenKm,
    required this.tripGameHours,
    required this.revenue,
    required this.energy,
    required this.toll,
    required this.crew,
    required this.maintenance,
    required this.expectedFines,
    required this.expectedAccident,
    required this.fineIfCaught,
    required this.accidentChance,
    required this.accidentCostIfHit,
  });

  final int vehicleTier;
  final String routeId;
  final String cargoName;

  /// Load actually carried after the max load cap.
  final double loadT;
  final double tonsOver;
  final double overloadRatio;
  final double drivenKm;
  final double tripGameHours;

  final double revenue;
  final double energy;
  final double toll;
  final double crew;
  final double maintenance;

  /// Expected value: weighbridges x check chance x fine.
  final double expectedFines;

  /// Expected value: accident chance x accident cost.
  final double expectedAccident;

  /// Fine for a single weighbridge catch. The sim rolls each weighbridge.
  final double fineIfCaught;

  /// Chance of an accident on this trip, for the sim's roll.
  final double accidentChance;

  /// Cost if the accident happens.
  final double accidentCostIfHit;

  double get totalCost =>
      energy + toll + crew + maintenance + expectedFines + expectedAccident;

  double get profit => revenue - totalCost;

  /// Profit / revenue. Zero when revenue is zero.
  double get margin => revenue > 0 ? profit / revenue : 0;

  int get revenueTk => revenue.round();
  int get energyTk => energy.round();
  int get tollTk => toll.round();
  int get crewTk => crew.round();
  int get maintenanceTk => maintenance.round();
  int get expectedFinesTk => expectedFines.round();
  int get expectedAccidentTk => expectedAccident.round();
  int get totalCostTk => totalCost.round();
  int get profitTk => profit.round();
}
