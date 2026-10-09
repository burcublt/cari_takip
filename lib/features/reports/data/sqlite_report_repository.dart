import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:cari_takip/features/reports/domain/report_repository.dart';
import 'package:cari_takip/features/reports/domain/report_result.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteReportRepository implements ReportRepository {
  SqliteReportRepository(this._db);

  final Database _db;

  @override
  Future<ReportResult> getReport(ReportFilter filter) async {
    try {
      final from = filter.fromDate;
      final to = filter.toDate;
      if (from != null && to != null && from.isAfter(to)) {
        throw const AppException(
          AppErrorKind.validation,
          'Başlangıç tarihi bitiş tarihinden sonra olamaz.',
        );
      }

      // Satırlar ve toplam aynı okuma işleminde alınır (tutarlı görüntü).
      return await _db.transaction((txn) async {
        final customer = await txn.query(
          'customers',
          columns: ['first_name', 'last_name'],
          where: 'id = ?',
          whereArgs: [filter.customerId],
          limit: 1,
        );
        if (customer.isEmpty) {
          throw const AppException(AppErrorKind.notFound, 'Cari bulunamadı.');
        }

        // Yalnızca sabit SQL parçaları birleştirilir; değerler `?` ile bağlanır.
        final (where, args) = _where(filter);

        final rows = await txn.rawQuery(
          'SELECT ft.id, ft.transaction_date, '
          'tt.name AS transaction_type_name, ft.amount_kurus, ft.note '
          'FROM financial_transactions ft '
          'JOIN transaction_types tt ON tt.id = ft.transaction_type_id '
          'WHERE $where '
          'ORDER BY ft.transaction_date DESC, ft.id DESC',
          args,
        );
        final total = await txn.rawQuery(
          'SELECT COALESCE(SUM(ft.amount_kurus), 0) AS total '
          'FROM financial_transactions ft WHERE $where',
          args,
        );

        final first = customer.first['first_name']! as String;
        final last = customer.first['last_name'] as String?;
        return ReportResult(
          filter: filter,
          customerName: last == null || last.isEmpty ? first : '$first $last',
          rows: rows.map(_fromRow).toList(),
          totalKurus: total.first['total']! as int,
        );
      });
    } on Object catch (error, stack) {
      throw ErrorMapper.map(error, stackTrace: stack);
    }
  }

  (String, List<Object?>) _where(ReportFilter filter) {
    final clauses = <String>['ft.customer_id = ?'];
    final args = <Object?>[filter.customerId];

    final typeId = filter.transactionTypeId;
    final from = filter.fromDate;
    final to = filter.toDate;

    if (typeId != null) {
      clauses.add('ft.transaction_type_id = ?');
      args.add(typeId);
    }
    if (from != null) {
      clauses.add('ft.transaction_date >= ?');
      args.add(AppDate.toDbDate(from));
    }
    if (to != null) {
      clauses.add('ft.transaction_date <= ?');
      args.add(AppDate.toDbDate(to));
    }
    return (clauses.join(' AND '), args);
  }

  ReportRow _fromRow(Map<String, Object?> row) {
    return ReportRow(
      id: row['id']! as int,
      transactionDate: DateTime.parse(row['transaction_date']! as String),
      transactionTypeName: row['transaction_type_name']! as String,
      amountKurus: row['amount_kurus']! as int,
      note: row['note'] as String?,
    );
  }
}
