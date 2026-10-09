import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boş filtre isEmpty, dolu filtre değil', () {
    expect(const TransactionFilter().isEmpty, isTrue);
    expect(const TransactionFilter(customerId: 1).isEmpty, isFalse);
    expect(const TransactionFilter(transactionTypeId: 2).isEmpty, isFalse);
    expect(TransactionFilter(fromDate: DateTime(2026)).isEmpty, isFalse);
    expect(TransactionFilter(toDate: DateTime(2026)).isEmpty, isFalse);
  });

  test('aynı değerli filtreler eşit ve aynı hashCode taşır (family anahtarı)',
      () {
    final a = TransactionFilter(
      customerId: 1,
      transactionTypeId: 2,
      fromDate: DateTime(2026, 9),
      toDate: DateTime(2026, 9, 30),
    );
    final b = TransactionFilter(
      customerId: 1,
      transactionTypeId: 2,
      fromDate: DateTime(2026, 9),
      toDate: DateTime(2026, 9, 30),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == a.withCustomer(3), isFalse);
  });

  test('with* yalnızca ilgili alanı değiştirir; null ile temizler', () {
    final filter = TransactionFilter(
      customerId: 1,
      transactionTypeId: 2,
      fromDate: DateTime(2026, 9),
      toDate: DateTime(2026, 9, 30),
    );

    expect(filter.withCustomer(null).customerId, isNull);
    expect(filter.withCustomer(null).transactionTypeId, 2);
    expect(filter.withType(null).transactionTypeId, isNull);
    expect(filter.withType(null).customerId, 1);
    expect(filter.withFrom(null).fromDate, isNull);
    expect(filter.withFrom(null).toDate, DateTime(2026, 9, 30));
    expect(filter.withTo(null).toDate, isNull);
    expect(filter.withTo(null).fromDate, DateTime(2026, 9));
  });
}
