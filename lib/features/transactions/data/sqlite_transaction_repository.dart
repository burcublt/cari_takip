import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/domain/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteTransactionRepository implements TransactionRepository {
  SqliteTransactionRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _notFound = AppException(
    AppErrorKind.notFound,
    'Finans hareketi bulunamadı.',
  );

  static const _select = '''
SELECT t.id, t.customer_id, t.transaction_type_id, t.direction,
       t.transaction_date,
       t.amount_kurus, t.note, t.created_at, t.updated_at,
       c.first_name, c.last_name, tt.name AS type_name
FROM financial_transactions t
JOIN customers c ON c.id = t.customer_id
JOIN transaction_types tt ON tt.id = t.transaction_type_id''';

  static const _order = 'ORDER BY t.transaction_date DESC, t.id DESC';

  @override
  Future<List<FinancialTransaction>> getTransactions({
    TransactionFilter filter = const TransactionFilter(),
    int? limit,
  }) {
    return _guard(() async {
      final (where, args) = _where(filter);
      final rows = await _db.rawQuery(
        '$_select $where $_order${limit == null ? '' : ' LIMIT ?'}',
        [...args, if (limit != null) limit],
      );
      return rows.map(_fromRow).toList();
    });
  }

  @override
  Future<List<FinancialTransaction>> getTransactionsByCustomer(
    int customerId, {
    int? limit,
  }) {
    return getTransactions(
      filter: TransactionFilter(customerId: customerId),
      limit: limit,
    );
  }

  @override
  Future<FinancialTransaction?> getTransactionById(int id) {
    return _guard(() async {
      final rows = await _db.rawQuery('$_select WHERE t.id = ?', [id]);
      return rows.isEmpty ? null : _fromRow(rows.first);
    });
  }

  @override
  Future<int> getTransactionTotalKurus({
    TransactionFilter filter = const TransactionFilter(),
  }) {
    return _guard(() async {
      final (where, args) = _where(filter);
      final rows = await _db.rawQuery(
        'SELECT COALESCE(SUM(CASE WHEN t.direction = ? '
        'THEN -t.amount_kurus ELSE t.amount_kurus END), 0) AS total '
        'FROM financial_transactions t $where',
        [TransactionDirection.debt.dbValue, ...args],
      );
      return rows.first['total']! as int;
    });
  }

  @override
  Future<FinancialTransaction> createTransaction(TransactionDraft draft) {
    return _guard(() async {
      final id = await _db.transaction((txn) async {
        await _validate(txn, draft);
        final now = AppDate.nowTimestamp(_now());
        return txn.insert('financial_transactions', {
          ..._values(draft),
          'created_at': now,
          'updated_at': now,
        });
      });
      final created = await getTransactionById(id);
      return created!;
    });
  }

  @override
  Future<FinancialTransaction> updateTransaction(
    int id,
    TransactionDraft draft,
  ) {
    return _guard(() async {
      await _db.transaction((txn) async {
        await _validate(txn, draft);
        final count = await txn.update(
          'financial_transactions',
          {..._values(draft), 'updated_at': AppDate.nowTimestamp(_now())},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count == 0) throw _notFound;
      });
      final updated = await getTransactionById(id);
      return updated!;
    });
  }

  @override
  Future<void> deleteTransaction(int id) {
    return _guard(() async {
      final count = await _db.delete(
        'financial_transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw _notFound;
    });
  }

  Future<void> _validate(DatabaseExecutor db, TransactionDraft draft) async {
    final amountError = Validators.amountKurus(draft.amountKurus);
    if (amountError != null) {
      throw AppException(AppErrorKind.validation, amountError);
    }
    if (!await _exists(db, 'customers', draft.customerId)) {
      throw const AppException(AppErrorKind.validation, 'Cari bulunamadı.');
    }
    if (!await _exists(db, 'transaction_types', draft.transactionTypeId)) {
      throw const AppException(
        AppErrorKind.validation,
        'İşlem tipi bulunamadı.',
      );
    }
  }

  Future<bool> _exists(DatabaseExecutor db, String table, int id) async {
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Map<String, Object?> _values(TransactionDraft draft) {
    final note = draft.note?.trim();
    return {
      'customer_id': draft.customerId,
      'transaction_type_id': draft.transactionTypeId,
      'direction': draft.direction.dbValue,
      'transaction_date': AppDate.toDbDate(draft.transactionDate),
      'amount_kurus': draft.amountKurus,
      'note': note == null || note.isEmpty ? null : note,
    };
  }

  (String, List<Object?>) _where(TransactionFilter filter) {
    final clauses = <String>[];
    final args = <Object?>[];

    final customerId = filter.customerId;
    final typeId = filter.transactionTypeId;
    final from = filter.fromDate;
    final to = filter.toDate;

    if (customerId != null) {
      clauses.add('t.customer_id = ?');
      args.add(customerId);
    }
    if (typeId != null) {
      clauses.add('t.transaction_type_id = ?');
      args.add(typeId);
    }
    if (from != null) {
      clauses.add('t.transaction_date >= ?');
      args.add(AppDate.toDbDate(from));
    }
    if (to != null) {
      clauses.add('t.transaction_date <= ?');
      args.add(AppDate.toDbDate(to));
    }

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return (where, args);
  }

  FinancialTransaction _fromRow(Map<String, Object?> row) {
    final first = row['first_name']! as String;
    final last = row['last_name'] as String?;
    return FinancialTransaction(
      id: row['id']! as int,
      customerId: row['customer_id']! as int,
      customerName: last == null || last.isEmpty ? first : '$first $last',
      transactionTypeId: row['transaction_type_id']! as int,
      transactionTypeName: row['type_name']! as String,
      direction: TransactionDirection.fromDbValue(row['direction']! as String),
      transactionDate: DateTime.parse(row['transaction_date']! as String),
      amountKurus: row['amount_kurus']! as int,
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error, stack) {
      throw ErrorMapper.map(error, stackTrace: stack);
    }
  }
}
