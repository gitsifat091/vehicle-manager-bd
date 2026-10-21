import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the translation files: same keys, same placeholders, one language
/// per string, no em dashes. Runs on the real files in lib/l10n.
void main() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;

  final en = load('app_en.arb');
  final bn = load('app_bn.arb');

  Map<String, String> messages(Map<String, dynamic> arb) => {
    for (final e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };

  final enMessages = messages(en);
  final bnMessages = messages(bn);

  /// The placeholders a message declares in the English template's metadata.
  Set<String> declared(String key) {
    final meta = en['@$key'] as Map<String, dynamic>;
    final placeholders = meta['placeholders'] as Map<String, dynamic>?;
    return placeholders?.keys.toSet() ?? {};
  }

  /// Placeholder names a message uses: `{name}` or `{name, select, ...}`.
  Set<String> used(String message, Set<String> names) => {
    for (final name in names)
      if (message.contains('{$name}') || message.contains('{$name,')) name,
  };

  /// The words a reader sees: the message without its placeholders and the
  /// select syntax (header, option names and braces).
  String visibleText(String message) {
    return message
        .replaceAll(RegExp(r'\{\w+,\s*select,\s*'), '')
        .replaceAll(RegExp(r'\b[A-Za-z]\w*(?=\{)'), '')
        .replaceAll(RegExp(r'\{[A-Za-z_]\w*\}'), '')
        .replaceAll(RegExp(r'[{}]'), '');
  }

  test('both languages have the same keys', () {
    expect(bnMessages.keys.toSet(), enMessages.keys.toSet());
  });

  test('every key in the English template is described', () {
    for (final key in enMessages.keys) {
      expect(en.containsKey('@$key'), true, reason: '$key has no @$key');
    }
  });

  test('every declared placeholder is used in both languages', () {
    for (final key in enMessages.keys) {
      final names = declared(key);
      expect(used(enMessages[key]!, names), names, reason: 'en $key');
      expect(used(bnMessages[key]!, names), names, reason: 'bn $key');
    }
  });

  test('a message with braces declares them', () {
    for (final e in enMessages.entries) {
      if (e.value.contains('{')) {
        expect(declared(e.key), isNotEmpty, reason: e.key);
      }
    }
  });

  test('every select message has an other option in both languages', () {
    for (final key in enMessages.keys) {
      if (!enMessages[key]!.contains(', select,')) continue;
      expect(enMessages[key]!.contains('other{'), true, reason: 'en $key');
      expect(bnMessages[key]!.contains('other{'), true, reason: 'bn $key');
    }
  });

  test('English strings contain no Bangla letters', () {
    final bangla = RegExp(r'[ঀ-৿]');
    for (final e in enMessages.entries) {
      expect(bangla.hasMatch(e.value), false, reason: e.key);
    }
  });

  test('Bangla strings contain no English letters outside placeholders', () {
    final latin = RegExp(r'[A-Za-z]');
    for (final e in bnMessages.entries) {
      expect(
        latin.hasMatch(visibleText(e.value)),
        false,
        reason: '${e.key}: ${e.value}',
      );
    }
  });

  test('no em dashes or en dashes anywhere', () {
    for (final name in ['app_en.arb', 'app_bn.arb']) {
      final text = File('lib/l10n/$name').readAsStringSync();
      expect(text.contains('—'), false, reason: '$name has an em dash');
      expect(text.contains('–'), false, reason: '$name has an en dash');
    }
  });

  test('no string is empty', () {
    for (final e in [...enMessages.entries, ...bnMessages.entries]) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
    }
  });

  test('the generated Dart files are current', () {
    final generated = File(
      'lib/l10n/app_localizations_en.dart',
    ).readAsStringSync();
    for (final key in enMessages.keys) {
      expect(
        generated.contains(key),
        true,
        reason: 'run flutter gen-l10n: $key',
      );
    }
  });
}
