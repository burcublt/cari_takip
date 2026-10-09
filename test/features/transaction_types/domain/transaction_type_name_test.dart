import 'package:cari_takip/features/transaction_types/domain/transaction_type_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalize trim eder ve iç boşlukları tek boşluğa indirir', () {
    expect(normalizeTransactionTypeName('  Muhasebe   Ücreti '), 'Muhasebe Ücreti');
    expect(normalizeTransactionTypeName('Kira'), 'Kira');
  });

  test('isSame Türkçe harf ve aksan farkını yok sayar', () {
    expect(isSameTransactionTypeName('Borç', 'BORÇ'), isTrue);
    expect(isSameTransactionTypeName('Borç', 'borc'), isTrue);
    expect(isSameTransactionTypeName('İş', 'iş'), isTrue);
    expect(isSameTransactionTypeName('Kira', 'Kiralar'), isFalse);
  });

  test('compare alfabetik sıralar', () {
    final names = ['Vergi', 'Çek', 'Borç', 'İcra']
      ..sort(compareTransactionTypeNames);
    expect(names, ['Borç', 'Çek', 'İcra', 'Vergi']);
  });
}
