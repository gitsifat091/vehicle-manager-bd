import '../config/economy_config.dart';
import 'purchase_rules.dart';
import 'route_economics.dart';

/// What selling one vehicle to buy another would do, for the sell screen.
///
/// Money is whole Taka; per-hour figures are real hours at 1x, like
/// [swapPaybackHours]. Route demand is not checked here: the buy screen
/// shows it next to the hint.
class SwapHint {
  const SwapHint({
    required this.resaleTk,
    required this.lossTk,
    required this.profitGainPerRealHour,
    required this.paybackRealHours,
    required this.boughtJob,
  });

  /// What the sale pays.
  final int resaleTk;

  /// The part of the sold vehicle's price the sale does not return.
  final int lossTk;

  /// Profit per real hour of the new job minus the old one. Can be negative.
  final double profitGainPerRealHour;

  /// Real hours at 1x until the gain has paid back [lossTk], or null when it
  /// never does.
  final double? paybackRealHours;

  /// What the new vehicle is assumed to do.
  final RouteEconomics boughtJob;

  bool get paysBack => paybackRealHours != null;
}

/// The hint for selling [sold] to buy the vehicle of [boughtJob].
///
/// [soldJob] is what the sold vehicle earns now: its assigned route and cargo
/// (`routeEconomics`), or null when it is idle and earns nothing.
SwapHint swapHint({
  required EconomySettings settings,
  required VehicleSpec sold,
  RouteEconomics? soldJob,
  required RouteEconomics boughtJob,
}) {
  final soldPerHour = soldJob?.profitPerRealHour ?? 0;
  final boughtPerHour = boughtJob.profitPerRealHour;
  final resale = resaleValueTk(settings: settings, vehicle: sold);
  return SwapHint(
    resaleTk: resale,
    lossTk: sold.priceTk - resale,
    profitGainPerRealHour: boughtPerHour - soldPerHour,
    paybackRealHours: swapPaybackHours(
      settings: settings,
      sold: sold,
      soldProfitPerHour: soldPerHour,
      boughtProfitPerHour: boughtPerHour,
    ),
    boughtJob: boughtJob,
  );
}

/// The job a newly bought [vehicle] most likely takes, for [swapHint]: the
/// best cargo on [routeId] when it can run that route and earns there (a
/// like-for-like swap keeps the route), otherwise its route and cargo with
/// the highest profit per hour. Null when it earns money nowhere.
RouteEconomics? likelyJobFor({
  required EconomyConfig config,
  required VehicleSpec vehicle,
  String? routeId,
}) {
  if (routeId != null) {
    final same = bestCargoOn(
      config: config,
      vehicle: vehicle,
      route: config.routeById(routeId),
    );
    if (same != null && same.paybackRealHours != null) return same;
  }
  RouteEconomics? best;
  for (final e in bestCargoPerRoute(config: config, vehicle: vehicle)) {
    if (e.paybackRealHours == null) continue;
    if (best == null || e.profitPerRealHour > best.profitPerRealHour) {
      best = e;
    }
  }
  return best;
}
