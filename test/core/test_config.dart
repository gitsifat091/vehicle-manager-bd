import 'dart:io';

import 'package:vehicle_manager_bd/core/config/economy_config.dart';

/// Path is relative to the project root, where `flutter test` runs.
const economyJsonPath = 'assets/config/economy.json';

String readEconomyJson() => File(economyJsonPath).readAsStringSync();

EconomyConfig loadDefaultConfig() => EconomyConfig.parse(readEconomyJson());
