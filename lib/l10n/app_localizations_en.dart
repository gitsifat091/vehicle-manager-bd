// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vehicle Manager Bangladesh';

  @override
  String get noGameYet => 'No game yet';

  @override
  String cashLine(String amount) {
    return 'Cash: $amount';
  }

  @override
  String turboLine(String speed) {
    return 'Turbo Start speed: $speed times';
  }
}
