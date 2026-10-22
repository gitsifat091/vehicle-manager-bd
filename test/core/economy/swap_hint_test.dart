import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/purchase_rules.dart';
import 'package:vehicle_manager_bd/core/economy/route_economics.dart';
import 'package:vehicle_manager_bd/core/economy/swap_hint.dart';

import '../test_config.dart';

void main() {
  final config = loadDefaultConfig();
  final settings = config.settings;

  RouteEconomics job(int tier, String routeId, String cargo) => routeEconomics(
    config: config,
    vehicle: config.vehicleByTier(tier),
    route: config.routeById(routeId),
    cargo: config.cargoByName(cargo),
  );

  group('swapHint', () {
    test('an idle vehicle earns nothing, so the whole new profit is gain', () {
      final bought = job(4, 'R01', 'General dry');
      final hint = swapHint(
        settings: settings,
        sold: config.vehicleByTier(2),
        boughtJob: bought,
      );
      // Bijli Cargo: Tk 1,50,000, resale 60 percent.
      expect(hint.resaleTk, 90000);
      expect(hint.lossTk, 60000);
      expect(hint.profitGainPerRealHour, bought.profitPerRealHour);
      expect(hint.paybackRealHours, 60000 / bought.profitPerRealHour);
      expect(hint.paysBack, true);
      expect(hint.boughtJob, same(bought));
    });

    test('a working vehicle: the gain is the difference of the two jobs', () {
      final sold = job(2, 'R01', 'Parcels');
      final bought = job(4, 'R01', 'General dry');
      final hint = swapHint(
        settings: settings,
        sold: sold.vehicle,
        soldJob: sold,
        boughtJob: bought,
      );
      final gain = bought.profitPerRealHour - sold.profitPerRealHour;
      expect(hint.profitGainPerRealHour, closeTo(gain, 1e-9));
      expect(
        hint.paybackRealHours,
        swapPaybackHours(
          settings: settings,
          sold: sold.vehicle,
          soldProfitPerHour: sold.profitPerRealHour,
          boughtProfitPerHour: bought.profitPerRealHour,
        ),
      );
    });

    test('the starter is valued at its fixed sale value', () {
      final sold = job(4, 'R01', 'General dry');
      final bought = job(6, 'R05', 'General dry');
      final hint = swapHint(
        settings: settings,
        sold: sold.vehicle,
        soldJob: sold,
        boughtJob: bought,
        soldIsStarter: true,
      );
      expect(hint.soldIsStarter, true);
      expect(hint.resaleTk, 150000);
      expect(hint.lossTk, 1300000 - 150000);
      expect(
        hint.paybackRealHours,
        closeTo((1300000 - 150000) / hint.profitGainPerRealHour, 1e-9),
      );

      final bought2 = swapHint(
        settings: settings,
        sold: sold.vehicle,
        soldJob: sold,
        boughtJob: bought,
      );
      expect(bought2.soldIsStarter, false);
      expect(bought2.resaleTk, 780000);
    });

    test('a worse new job never pays back', () {
      final sold = job(4, 'R01', 'General dry');
      final bought = job(1, 'M01', 'Market goods');
      final hint = swapHint(
        settings: settings,
        sold: sold.vehicle,
        soldJob: sold,
        boughtJob: bought,
      );
      expect(hint.profitGainPerRealHour, lessThan(0));
      expect(hint.paybackRealHours, isNull);
      expect(hint.paysBack, false);
    });
  });

  group('likelyJobFor', () {
    test('keeps the route of the sold vehicle when it can', () {
      final e = likelyJobFor(
        config: config,
        vehicle: config.vehicleByTier(4),
        routeId: 'R01',
      )!;
      expect(e.route.id, 'R01');
      expect(
        e.profitPerRealHour,
        bestCargoOn(
          config: config,
          vehicle: config.vehicleByTier(4),
          route: config.routeById('R01'),
        )!.profitPerRealHour,
      );
    });

    test('a route it cannot run falls back to its best route', () {
      // Tier 1 runs only M01 and M02.
      final e = likelyJobFor(
        config: config,
        vehicle: config.vehicleByTier(1),
        routeId: 'R05',
      )!;
      expect(['M01', 'M02'], contains(e.route.id));
    });

    test('without a route it is the best profit per hour anywhere', () {
      final vehicle = config.vehicleByTier(6);
      final e = likelyJobFor(config: config, vehicle: vehicle)!;
      for (final other in bestCargoPerRoute(config: config, vehicle: vehicle)) {
        expect(
          e.profitPerRealHour,
          greaterThanOrEqualTo(other.profitPerRealHour),
          reason: other.route.id,
        );
      }
      expect(e.paybackRealHours, isNotNull);
    });
  });
}
