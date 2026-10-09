import 'package:cari_takip/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cari adı', () {
    test('boş, null veya sadece boşluk geçersiz', () {
      expect(Validators.customerName(null), isNotNull);
      expect(Validators.customerName(''), isNotNull);
      expect(Validators.customerName('   '), isNotNull);
    });

    test('geçerli ad', () {
      expect(Validators.customerName('Ahmet Yılmaz'), isNull);
      expect(Validators.customerName('  Yılmaz Ltd. '), isNull);
    });
  });

  group('işlem tipi adı', () {
    test('boş geçersiz', () {
      expect(Validators.transactionTypeName(null), isNotNull);
      expect(Validators.transactionTypeName(' '), isNotNull);
    });

    test('geçerli ad', () {
      expect(Validators.transactionTypeName('Kira'), isNull);
    });
  });

  group('zorunlu seçimler', () {
    test('cari, tip ve tarih', () {
      expect(Validators.customer(null), isNotNull);
      expect(Validators.customer(1), isNull);
      expect(Validators.transactionType(null), isNotNull);
      expect(Validators.transactionType(2), isNull);
      expect(Validators.transactionDate(null), isNotNull);
      expect(Validators.transactionDate(DateTime(2026, 9, 29)), isNull);
    });
  });

  group('tutar (form girdisi)', () {
    test('boş girdi geçersiz', () {
      expect(Validators.amount(null), isNotNull);
      expect(Validators.amount(''), isNotNull);
      expect(Validators.amount('  '), isNotNull);
    });

    test('sayı olmayan girdi geçersiz', () {
      expect(Validators.amount('abc'), contains('Geçerli'));
      expect(Validators.amount('12.5'), contains('Geçerli'));
    });

    test('sıfır ve negatif tutar geçersiz', () {
      expect(Validators.amount('0'), contains("0'dan büyük"));
      expect(Validators.amount('0,00'), contains("0'dan büyük"));
      expect(Validators.amount('-5'), contains("0'dan büyük"));
    });

    test('geçerli tutar', () {
      expect(Validators.amount('0,01'), isNull);
      expect(Validators.amount('1.250,50'), isNull);
      expect(Validators.amount('100'), isNull);
    });
  });

  group('tutar (kuruş)', () {
    test('null, sıfır ve negatif geçersiz; pozitif geçerli', () {
      expect(Validators.amountKurus(null), isNotNull);
      expect(Validators.amountKurus(0), isNotNull);
      expect(Validators.amountKurus(-1), isNotNull);
      expect(Validators.amountKurus(1), isNull);
    });
  });
}
