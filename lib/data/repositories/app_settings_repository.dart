import 'package:hive_ce/hive_ce.dart';

/// Settings that belong to this device, not to a save: the language and the
/// theme. A new game does not erase them.
///
/// Plain strings, so there is no adapter to keep in step. A missing value
/// means "use the default".
class AppSettingsRepository {
  AppSettingsRepository(this.box);

  static const _languageKey = 'language';
  static const _themeKey = 'theme_mode';

  final Box<String> box;

  /// 'en', 'bn', or null to follow the device.
  String? get languageCode => box.get(_languageKey);

  Future<void> setLanguageCode(String? code) {
    return code == null
        ? box.delete(_languageKey)
        : box.put(_languageKey, code);
  }

  /// 'light', 'dark', or null to follow the device.
  String? get themeMode => box.get(_themeKey);

  Future<void> setThemeMode(String? mode) {
    return mode == null ? box.delete(_themeKey) : box.put(_themeKey, mode);
  }
}
