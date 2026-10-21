import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/data/repositories/save_database.dart';
import 'package:vehicle_manager_bd/state/app_settings.dart';

import '../data/save_test_helper.dart';
import '../support/sim_support.dart';

void main() {
  final folder = SaveFolder()..register();
  late SaveDatabase db;

  setUp(() async {
    db = await folder.open();
  });

  /// Closes and reopens the save, as a restart of the app does.
  Future<AppSettings> restart() async {
    await db.close();
    db = await folder.open();
    return AppSettings(db.settings);
  }

  test('defaults: follow the device language and theme', () {
    final settings = AppSettings(db.settings);
    expect(settings.languageCode, isNull);
    expect(settings.locale, isNull);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('the language is chosen, notified and remembered', () async {
    final settings = AppSettings(db.settings);
    var heard = 0;
    settings.addListener(() => heard++);

    await settings.setLanguage('bn');
    expect(settings.locale, const Locale('bn'));
    expect(heard, 1);

    final again = await restart();
    expect(again.languageCode, 'bn');
    expect(again.locale, const Locale('bn'));
  });

  test('going back to the device language forgets the choice', () async {
    final settings = AppSettings(db.settings);
    await settings.setLanguage('en');
    await settings.setLanguage(null);
    expect(settings.locale, isNull);
    expect((await restart()).languageCode, isNull);
  });

  test('a language the app has no ARB file for is ignored', () async {
    final settings = AppSettings(db.settings);
    await settings.setLanguage('fr');
    expect(settings.languageCode, isNull);

    await db.settings.setLanguageCode('xx');
    expect((await restart()).languageCode, isNull, reason: 'bad saved value');
  });

  test('setting the same language again does not notify', () async {
    final settings = AppSettings(db.settings);
    await settings.setLanguage('bn');
    var heard = 0;
    settings.addListener(() => heard++);
    await settings.setLanguage('bn');
    expect(heard, 0);
  });

  test('the theme mode is chosen and remembered', () async {
    final settings = AppSettings(db.settings);
    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.dark);
    expect((await restart()).themeMode, ThemeMode.dark);

    final again = AppSettings(db.settings);
    await again.setThemeMode(ThemeMode.light);
    expect((await restart()).themeMode, ThemeMode.light);

    final last = AppSettings(db.settings);
    await last.setThemeMode(ThemeMode.system);
    expect((await restart()).themeMode, ThemeMode.system);
  });

  test('a bad saved theme falls back to the device theme', () async {
    await db.settings.setThemeMode('purple');
    expect((await restart()).themeMode, ThemeMode.system);
  });

  test('a new game does not erase the device settings', () async {
    final settings = AppSettings(db.settings);
    await settings.setLanguage('bn');
    await settings.setThemeMode(ThemeMode.dark);
    await db.company.save(Company(name: 'Old', cash: 1, createdAt: t0));

    await db.clearAll();
    expect(db.company.exists, false);
    final again = await restart();
    expect(again.languageCode, 'bn');
    expect(again.themeMode, ThemeMode.dark);
  });
}
