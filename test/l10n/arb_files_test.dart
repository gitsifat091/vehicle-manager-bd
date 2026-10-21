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
  final placeholder = RegExp(r'\{(\w+)[,}]');

  Set<String> placeholdersOf(String message) =>
      placeholder.allMatches(message).map((m) => m.group(1)!).toSet();

  test('both languages have the same keys', () {
    expect(bnMessages.keys.toSet(), enMessages.keys.toSet());
  });

  test('every key in the English template is described', () {
    for (final key in enMessages.keys) {
      expect(en.containsKey('@$key'), true, reason: '$key has no @$key');
    }
  });

  test('the Bangla strings use the same placeholders', () {
    for (final key in enMessages.keys) {
      expect(
        placeholdersOf(bnMessages[key]!),
        placeholdersOf(enMessages[key]!),
        reason: key,
      );
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
      final text = e.value.replaceAll(RegExp(r'\{[^}]*\}'), '');
      expect(latin.hasMatch(text), false, reason: '${e.key}: ${e.value}');
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
