import 'package:flutter/material.dart';

import '../data/repositories/app_settings_repository.dart';

/// The language and theme the player chose, saved on this device.
///
/// Language null means "follow the device" (Bangla on a Bangla phone, English
/// otherwise). The app puts this in the widget tree, so a change redraws
/// everything in the new language at once.
class AppSettings extends ChangeNotifier {
  AppSettings(this._repository)
    : _languageCode = _validLanguage(_repository.languageCode),
      _themeMode = _themeFrom(_repository.themeMode);

  /// The languages the app has ARB files for.
  static const supportedLanguages = ['en', 'bn'];

  final AppSettingsRepository _repository;
  String? _languageCode;
  ThemeMode _themeMode;

  /// 'en', 'bn', or null to follow the device.
  String? get languageCode => _languageCode;

  /// The chosen locale, or null so Flutter picks from the device.
  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  ThemeMode get themeMode => _themeMode;

  Future<void> setLanguage(String? code) async {
    final valid = _validLanguage(code);
    if (valid == _languageCode) return;
    _languageCode = valid;
    notifyListeners();
    await _repository.setLanguageCode(valid);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _repository.setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    });
  }

  static String? _validLanguage(String? code) =>
      supportedLanguages.contains(code) ? code : null;

  static ThemeMode _themeFrom(String? saved) => switch (saved) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
