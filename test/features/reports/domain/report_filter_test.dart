import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:cari_takip/features/reports/domain/report_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aynı değerli filtreler eşit ve aynı hashCode taşır', () {
    final a = ReportFilter(
      customerId: 1,
      transactionTypeId: 2,
      fromDate: DateTime(2026, 9),
      toDate: DateTime(2026, 9, 30),
    );
    final b = ReportFilter(
      customerId: 1,
      transactionTypeId: 2,
      fromDate: DateTime(2026, 9),
      toDate: DateTime(2026, 9, 30),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == const ReportFilter(customerId: 1), isFalse);
    expect(a == const ReportFilter(customerId: 2), isFalse);
  });

  test('ReportResult.count satır sayısını verir', () {
    final result = ReportResult(
      filter: const ReportFilter(customerId: 1),
      customerName: 'Ali',
      rows: [
        ReportRow(
          id: 1,
          transactionDate: DateTime(2026, 9),
          transactionTypeName: 'Kira',
          amountKurus: 100,
        ),
      ],
      totalKurus: 100,
    );
    expect(result.count, 1);
  });
}
