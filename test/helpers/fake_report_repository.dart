import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:cari_takip/features/reports/domain/report_repository.dart';
import 'package:cari_takip/features/reports/domain/report_result.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';

import 'fake_transaction_repository.dart';

/// Sahte hareket repository'sinden rapor üretir (widget testleri için).
class FakeReportRepository implements ReportRepository {
  FakeReportRepository(this._transactions);

  final FakeTransactionRepository _transactions;

  @override
  Future<ReportResult> getReport(ReportFilter filter) async {
    final matches = _transactions.customers.customers
        .where((c) => c.id == filter.customerId);
    if (matches.isEmpty) {
      throw const AppException(AppErrorKind.notFound, 'Cari bulunamadı.');
    }

    final list = await _transactions.getTransactions(
      filter: TransactionFilter(
        customerId: filter.customerId,
        transactionTypeId: filter.transactionTypeId,
        fromDate: filter.fromDate,
        toDate: filter.toDate,
      ),
    );
    return ReportResult(
      filter: filter,
      customerName: matches.first.displayName,
      rows: [
        for (final t in list)
          ReportRow(
            id: t.id,
            transactionDate: t.transactionDate,
            transactionTypeName: t.transactionTypeName,
            amountKurus: t.amountKurus,
            note: t.note,
          ),
      ],
      totalKurus: list.fold<int>(0, (sum, t) => sum + t.amountKurus),
    );
  }
}
