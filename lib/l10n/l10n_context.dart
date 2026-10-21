import 'package:flutter/widgets.dart';

import '../core/format/formats.dart';
import 'app_localizations.dart';

/// Short access to the translated strings and the number formatter.
///
/// `context.l10n.appTitle` for text, `context.fmt.money(5000)` for numbers.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Formats numbers for the language the app is showing right now.
  Formats get fmt =>
      Formats(bangla: Localizations.localeOf(this).languageCode == 'bn');
}
