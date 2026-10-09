import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_repository.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteDashboardRepository implements DashboardRepository {
  SqliteDashboardRepository(
    this._db, {
    DateTime Function()? now,
    this.recentLimit = 5,
  }) : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;
  final int recentLimit;

  @override
  Future<DashboardSummary> getSummary() async {
    try {
      final today = AppDate.today(_now());
      final monthStart = AppDate.toDbDate(AppDate.startOfMonth(today));
      final monthEnd = AppDate.toDbDate(AppDate.endOfMonth(today));

      // Tüm değerler aynı okuma işleminde alınır (tutarlı görüntü).
      return await _db.transaction((txn) async {
        final customers = await txn.rawQuery(
          'SELECT COUNT(*) AS cnt FROM customers WHERE is_active = 1',
        );
        final all = await txn.rawQuery(
          'SELECT COUNT(*) AS cnt, COALESCE(SUM(amount_kurus), 0) AS total '
          'FROM financial_transactions',
        );
        final month = await txn.rawQuery(
          'SELECT COUNT(*) AS cnt, COALESCE(SUM(amount_kurus), 0) AS total '
          'FROM financial_transactions '
          'WHERE transaction_date >= ? AND transaction_date <= ?',
          [monthStart, monthEnd],
        );
        final recent = await txn.rawQuery(
          'SELECT t.id, t.transaction_date, t.amount_kurus, '
          'c.first_name, c.last_name, tt.name AS type_name '
          'FROM financial_transactions t '
          'JOIN customers c ON c.id = t.customer_id '
          'JOIN transaction_types tt ON tt.id = t.transaction_type_id '
          'ORDER BY t.transaction_date DESC, t.id DESC LIMIT ?',
          [recentLimit],
        );

        return DashboardSummary(
          activeCustomerCount: customers.first['cnt']! as int,
          transactionCount: all.first['cnt']! as int,
          totalAmountKurus: all.first['total']! as int,
          month: AppDate.startOfMonth(today),
          monthAmountKurus: month.first['total']! as int,
          monthTransactionCount: month.first['cnt']! as int,
          recentTransactions: recent.map(_recentFromRow).toList(),
        );
      });
    } on Object catch (error, stack) {
      throw ErrorMapper.map(error, stackTrace: stack);
    }
  }

  RecentTransaction _recentFromRow(Map<String, Object?> row) {
    final first = row['first_name']! as String;
    final last = row['last_name'] as String?;
    return RecentTransaction(
      id: row['id']! as int,
      transactionDate: DateTime.parse(row['transaction_date']! as String),
      customerName: last == null || last.isEmpty ? first : '$first $last',
      transactionTypeName: row['type_name']! as String,
      amountKurus: row['amount_kurus']! as int,
    );
  }
}
