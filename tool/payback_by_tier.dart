// Payback per vehicle tier on its best route, from assets/config/economy.json.
//
//   dart run tool/payback_by_tier.dart
//
// Same definition as docs/economy_model.xlsx (Trip Calculator, column AA):
// price / profit per real hour at 1x, with the vehicle running back to back at
// its legal payload and expected fines and accidents
// (lib/core/economy/route_economics.dart, the same code as the buy screen).
// Terminals and unlocks are ignored. It changes no numbers.

// ignore_for_file: avoid_print
import 'dart:io';

import 'package:vehicle_manager_bd/core/config/economy_config.dart';
import 'package:vehicle_manager_bd/core/economy/route_economics.dart';

import 'first_hours_sim.dart';

void main() {
  final config = EconomyConfig.parse(
    File('assets/config/economy.json').readAsStringSync(),
  );
  final gmpm = config.settings.gameMinutesPerRealMinute;

  print(
    'Tier  Vehicle          Price (Tk)   Best route (cargo)'
    '                 Profit/trip  Trip min  Profit/h (Tk)  Payback h  '
    'Vehicles the route holds',
  );
  for (final vehicle in config.vehicles) {
    final all = [
      for (final route in config.routes)
        ...allCargoOn(config: config, vehicle: vehicle, route: route),
    ];
    double payback(Candidate c) => c.paybackRealHours!;
    final earning = all.where((c) => c.paybackRealHours != null).toList()
      ..sort((a, b) => payback(a).compareTo(payback(b)));
    if (earning.isEmpty) {
      print('${vehicle.tier.toString().padLeft(4)}  ${vehicle.name}: loses '
          'money on every route');
      continue;
    }
    // One vehicle must fit in the route's daily demand, or it would starve.
    double holds(Candidate c) => c.vehiclesRouteHolds;
    final fits = earning.where((c) => holds(c) >= 1).toList();
    final best = fits.isEmpty ? earning.first : fits.first;
    final fastest = earning.first;

    String row(Candidate c, {String tag = ''}) {
      final minutes = c.quote.tripGameHours * 60 / gmpm;
      return '${vehicle.tier.toString().padLeft(4)}  '
          '${vehicle.name.padRight(15)}  '
          '${money(vehicle.priceTk).padLeft(10)}   '
          '${c.label.padRight(34)}'
          '${money(c.quote.profit.round()).padLeft(10)}  '
          '${minutes.toStringAsFixed(1).padLeft(8)}  '
          '${money(c.profitPerRealHour.round()).padLeft(13)}  '
          '${payback(c).toStringAsFixed(1).padLeft(9)}  '
          '${holds(c).toStringAsFixed(1).padLeft(6)}$tag';
    }

    print(row(best));
    if (!identical(fastest, best)) {
      print('${' ' * 4}  (shorter payback on ${fastest.route.id} '
          '${fastest.cargo.name}: ${payback(fastest).toStringAsFixed(1)} h, '
          'but the route holds only ${holds(fastest).toStringAsFixed(1)} '
          'of this vehicle)');
    }
  }
}
