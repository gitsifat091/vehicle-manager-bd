import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/format/formats.dart';

void main() {
  const en = Formats(bangla: false);
  const bn = Formats(bangla: true);

  group('integer: lakh and crore grouping', () {
    test('small numbers have no separator', () {
      expect(en.integer(0), '0');
      expect(en.integer(7), '7');
      expect(en.integer(999), '999');
    });

    test('thousands, lakh and crore', () {
      expect(en.integer(1000), '1,000');
      expect(en.integer(12345), '12,345');
      expect(en.integer(123456), '1,23,456');
      expect(en.integer(1500000), '15,00,000');
      expect(en.integer(3160000), '31,60,000');
      expect(en.integer(10000000), '1,00,00,000');
      expect(en.integer(1234567890), '1,23,45,67,890');
    });

    test('negative numbers keep the sign', () {
      expect(en.integer(-5), '-5');
      expect(en.integer(-123456), '-1,23,456');
    });

    test('Bangla digits', () {
      expect(bn.integer(3160000), '৩১,৬০,০০০');
      expect(bn.integer(0), '০');
      expect(bn.integer(-1500), '-১,৫০০');
    });
  });

  group('money', () {
    test('English: Tk with lakh grouping', () {
      expect(en.money(3160000), 'Tk 31,60,000');
      expect(en.money(1500000), 'Tk 15,00,000');
      expect(en.money(0), 'Tk 0');
      expect(en.money(2183), 'Tk 2,183');
    });

    test('Bangla: taka sign and Bangla digits', () {
      expect(bn.money(3160000), '৳ ৩১,৬০,০০০');
      expect(bn.money(20000), '৳ ২০,০০০');
      expect(bn.money(0), '৳ ০');
    });

    test('a loss puts the minus sign before the currency', () {
      expect(en.money(-5000), '-Tk 5,000');
      expect(bn.money(-5000), '-৳ ৫,০০০');
    });
  });

  group('decimal', () {
    test('drops trailing zeros', () {
      expect(en.decimal(60), '60');
      expect(en.decimal(1.5), '1.5');
      expect(en.decimal(58.4999), '58.5');
      expect(en.decimal(20, places: 0), '20');
    });

    test('keeps the places asked for', () {
      expect(en.decimal(0.125, places: 2), '0.13');
      expect(en.decimal(3.14159, places: 3), '3.142');
    });

    test('groups the whole part', () {
      expect(en.decimal(1234567.5), '12,34,567.5');
    });

    test('Bangla digits', () {
      expect(bn.decimal(1.5), '১.৫');
      expect(bn.decimal(60), '৬০');
      expect(bn.decimal(20, places: 0), '২০');
    });

    test('negative values, and no negative zero', () {
      expect(en.decimal(-2.5), '-2.5');
      expect(en.decimal(-0.01, places: 1), '0');
    });
  });

  group('clock', () {
    test('minutes and seconds under an hour', () {
      expect(en.clock(Duration.zero), '0:00');
      expect(en.clock(const Duration(seconds: 5)), '0:05');
      expect(en.clock(const Duration(minutes: 4, seconds: 5)), '4:05');
      expect(en.clock(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('hours from one hour on', () {
      expect(en.clock(const Duration(hours: 1)), '1:00:00');
      expect(
        en.clock(const Duration(hours: 1, minutes: 4, seconds: 5)),
        '1:04:05',
      );
      expect(en.clock(const Duration(hours: 10)), '10:00:00');
    });

    test('never negative, and Bangla digits', () {
      expect(en.clock(const Duration(seconds: -4)), '0:00');
      expect(bn.clock(const Duration(minutes: 4, seconds: 5)), '৪:০৫');
      expect(
        bn.clock(const Duration(hours: 1, minutes: 4, seconds: 5)),
        '১:০৪:০৫',
      );
    });
  });

  group('digits', () {
    test('English text is left alone', () {
      expect(en.digits('Tier 4'), 'Tier 4');
    });

    test('Bangla converts only the digits 0 to 9', () {
      expect(bn.digits('R01 1,5'), 'R০১ ১,৫');
      expect(bn.digits(''), '');
    });
  });
}
