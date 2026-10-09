import 'package:cari_takip/core/utils/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTlToKurus', () {
    test('sıfır ve tam liralar', () {
      expect(Currency.parseTlToKurus('0'), 0);
      expect(Currency.parseTlToKurus('0,00'), 0);
      expect(Currency.parseTlToKurus('1'), 100);
      expect(Currency.parseTlToKurus('1 TL'), 100);
    });

    test('kuruşlu tutar', () {
      expect(Currency.parseTlToKurus('1250,50'), 125050);
      expect(Currency.parseTlToKurus('1250,5'), 125050);
      expect(Currency.parseTlToKurus('0,05'), 5);
      expect(Currency.parseTlToKurus('0,5'), 50);
    });

    test('binlik ayırıcı ve sembol', () {
      expect(Currency.parseTlToKurus('1.250,50'), 125050);
      expect(Currency.parseTlToKurus('1.250'), 125000);
      expect(Currency.parseTlToKurus('12.450,75 TL'), 1245075);
      expect(Currency.parseTlToKurus('₺100'), 10000);
      expect(Currency.parseTlToKurus('  1.250,50  tl '), 125050);
    });

    test('milyonluk tutar', () {
      expect(Currency.parseTlToKurus('1.000.000,00'), 100000000);
      expect(Currency.parseTlToKurus('1.234.567,89'), 123456789);
    });

    test('negatif girdi negatif kuruş döner', () {
      expect(Currency.parseTlToKurus('-5'), -500);
      expect(Currency.parseTlToKurus('-1.250,50'), -125050);
    });

    test('hatalı girdi null döner', () {
      for (final input in [
        null,
        '',
        '   ',
        'abc',
        '-',
        ',50',
        '1250,',
        '12,345',
        '1,2,3',
        '12.5',
        '1.2500',
        '1..250',
        '12a',
        '1e5',
      ]) {
        expect(Currency.parseTlToKurus(input), isNull, reason: '$input');
      }
    });

    test('tam kısım 13 haneyi aşarsa geçersiz', () {
      expect(Currency.parseTlToKurus('9999999999999'), 999999999999900);
      expect(Currency.parseTlToKurus('10000000000000'), isNull);
    });
  });

  group('formatKurusToTl', () {
    test('temel biçimler', () {
      expect(Currency.formatKurusToTl(0), '0,00 TL');
      expect(Currency.formatKurusToTl(5), '0,05 TL');
      expect(Currency.formatKurusToTl(100), '1,00 TL');
      expect(Currency.formatKurusToTl(125050), '1.250,50 TL');
      expect(Currency.formatKurusToTl(1245075), '12.450,75 TL');
      expect(Currency.formatKurusToTl(100000000), '1.000.000,00 TL');
    });

    test('negatif tutar', () {
      expect(Currency.formatKurusToTl(-125050), '-1.250,50 TL');
    });

    test('birimsiz biçim', () {
      expect(Currency.formatKurusToTl(125050, includeUnit: false), '1.250,50');
    });

    test('format -> parse gidiş dönüş', () {
      for (final kurus in [0, 1, 99, 100, 101, 99999, 100000, 123456789]) {
        final text = Currency.formatKurusToTl(kurus, includeUnit: false);
        expect(Currency.parseTlToKurus(text), kurus, reason: text);
      }
    });
  });
}
