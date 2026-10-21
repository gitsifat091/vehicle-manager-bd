// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'ভেহিকেল ম্যানেজার বাংলাদেশ';

  @override
  String get noGameYet => 'এখনো কোনো খেলা শুরু হয়নি';

  @override
  String cashLine(String amount) {
    return 'নগদ: $amount';
  }

  @override
  String turboLine(String speed) {
    return 'টার্বো স্টার্টের গতি: $speed গুণ';
  }
}
