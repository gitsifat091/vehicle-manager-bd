import 'package:flutter/widgets.dart';

import '../core/format/formats.dart';
import 'app_localizations.dart';

/// Short access to the translated strings and the number formatter.
///
/// `context.l10n.appTitle` for text, `context.fmt.money(5000)` for numbers,
/// and `context.vehicleNameOf(4)` for names that come from the config.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Formats numbers for the language the app is showing right now.
  Formats get fmt =>
      Formats(bangla: Localizations.localeOf(this).languageCode == 'bn');

  /// The translated name of a vehicle tier (Sathi Plus, সাথী প্লাস).
  String vehicleNameOf(int tier) => l10n.vehicleName(vehicleKey(tier));

  /// The translated name of a route from its id, for example R01.
  String routeNameOf(String routeId) => l10n.routeName(routeKey(routeId));

  /// The translated name of a cargo type from its config name.
  String cargoNameOf(String cargoName) => l10n.cargoName(cargoKey(cargoName));
}

/// The select key the ARB files use for a vehicle tier: tier4.
String vehicleKey(int tier) => 'tier$tier';

/// The select key for a route: its id in lower case, r01.
String routeKey(String routeId) => routeId.toLowerCase();

/// The select key for a cargo: its English config name in camel case, so
/// 'Cement and rod' becomes cementAndRod.
String cargoKey(String cargoName) {
  final words = cargoName.split(' ').where((w) => w.isNotEmpty).toList();
  return [
    for (var i = 0; i < words.length; i++)
      i == 0
          ? words[i].toLowerCase()
          : words[i][0].toUpperCase() + words[i].substring(1).toLowerCase(),
  ].join();
}
