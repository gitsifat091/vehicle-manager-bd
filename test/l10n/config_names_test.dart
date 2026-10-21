import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/l10n/app_localizations.dart';
import 'package:vehicle_manager_bd/l10n/app_localizations_bn.dart';
import 'package:vehicle_manager_bd/l10n/app_localizations_en.dart';
import 'package:vehicle_manager_bd/l10n/l10n_context.dart';

import '../core/test_config.dart';

/// Vehicle, route and cargo names live in the ARB files, keyed by the config.
/// If someone adds one to economy.json and forgets the translation, the screen
/// would show the "other" fallback. These tests catch that.
void main() {
  final config = loadDefaultConfig();
  final languages = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'bn': AppLocalizationsBn(),
  };

  group('vehicles', () {
    test('every tier has a name in both languages, not the fallback', () {
      for (final entry in languages.entries) {
        final fallback = entry.value.vehicleName('unknown');
        final names = <String>{};
        for (final v in config.vehicles) {
          final name = entry.value.vehicleName(vehicleKey(v.tier));
          expect(name, isNot(fallback), reason: '${entry.key} tier ${v.tier}');
          names.add(name);
        }
        expect(names, hasLength(config.vehicles.length), reason: entry.key);
      }
    });

    test('the English names are the config names', () {
      for (final v in config.vehicles) {
        expect(
          languages['en']!.vehicleName(vehicleKey(v.tier)),
          v.name,
          reason: 'tier ${v.tier}',
        );
      }
    });
  });

  group('routes', () {
    test('every route has a name in both languages, not the fallback', () {
      for (final entry in languages.entries) {
        final fallback = entry.value.routeName('unknown');
        final names = <String>{};
        for (final r in config.routes) {
          final name = entry.value.routeName(routeKey(r.id));
          expect(name, isNot(fallback), reason: '${entry.key} ${r.id}');
          names.add(name);
        }
        expect(names, hasLength(config.routes.length), reason: entry.key);
      }
    });
  });

  group('cargo', () {
    test('every cargo has a name in both languages, not the fallback', () {
      for (final entry in languages.entries) {
        final fallback = entry.value.cargoName('unknown');
        final names = <String>{};
        for (final c in config.cargo) {
          final name = entry.value.cargoName(cargoKey(c.name));
          expect(name, isNot(fallback), reason: '${entry.key} ${c.name}');
          names.add(name);
        }
        expect(names, hasLength(config.cargo.length), reason: entry.key);
      }
    });

    test('the select key is the config name in camel case', () {
      expect(cargoKey('Market goods'), 'marketGoods');
      expect(cargoKey('General dry'), 'generalDry');
      expect(cargoKey('Cement and rod'), 'cementAndRod');
      expect(cargoKey('Fish'), 'fish');
    });
  });

  test('route and vehicle keys', () {
    expect(routeKey('R01'), 'r01');
    expect(routeKey('M02'), 'm02');
    expect(vehicleKey(12), 'tier12');
  });
}
