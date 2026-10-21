/// Number, money and time formatting for the UI, in English or Bangla.
///
/// Pure Dart so it can be unit tested without Flutter. Grouping is the South
/// Asian lakh and crore style: the last three digits, then pairs
/// (Tk 31,60,000 and ৳ ৩১,৬০,০০০). Bangla uses Bangla digits. The unit words
/// ("tons", "hours") are not here; they live in the ARB files.
class Formats {
  const Formats({required this.bangla});

  /// True for Bangla digits and the taka sign, false for English.
  final bool bangla;

  static const _banglaDigits = [
    '০',
    '১',
    '২',
    '৩',
    '৪',
    '৫',
    '৬',
    '৭',
    '৮',
    '৯',
  ];

  /// Replaces the digits 0 to 9 in [text] with Bangla digits when [bangla].
  String digits(String text) {
    if (!bangla) return text;
    final out = StringBuffer();
    for (final unit in text.codeUnits) {
      final d = unit - 0x30;
      out.write(
        d >= 0 && d <= 9 ? _banglaDigits[d] : String.fromCharCode(unit),
      );
    }
    return out.toString();
  }

  /// 1234567 -> 12,34,567. A negative number keeps its minus sign.
  String integer(int value) {
    final negative = value < 0;
    final grouped = _group(value.abs().toString());
    return digits(negative ? '-$grouped' : grouped);
  }

  /// Whole Taka with the currency sign: Tk 31,60,000 or ৳ ৩১,৬০,০০০. A loss
  /// puts the minus sign first: -Tk 5,000.
  String money(int taka) {
    final sign = bangla ? '৳' : 'Tk';
    final negative = taka < 0;
    final body = digits(_group(taka.abs().toString()));
    return negative ? '-$sign $body' : '$sign $body';
  }

  /// A number with at most [places] decimals and no trailing zeros:
  /// 60 -> 60, 1.5 -> 1.5, 58.4999 -> 58.5.
  String decimal(double value, {int places = 1}) {
    final negative = value < 0;
    var text = value.abs().toStringAsFixed(places);
    if (text.contains('.')) {
      text = text
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    final parts = text.split('.');
    final whole = _group(parts.first);
    final body = parts.length > 1 ? '$whole.${parts[1]}' : whole;
    return digits(negative && body != '0' ? '-$body' : body);
  }

  /// A timer: 4:05 under an hour, 1:04:05 from an hour on. Never negative.
  String clock(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return digits('$hours:${minutes.toString().padLeft(2, '0')}:$ss');
    }
    return digits('$minutes:$ss');
  }

  static String _group(String digitsOnly) {
    if (digitsOnly.length <= 3) return digitsOnly;
    final tail = digitsOnly.substring(digitsOnly.length - 3);
    var head = digitsOnly.substring(0, digitsOnly.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    return '${parts.join(',')},$tail';
  }
}
