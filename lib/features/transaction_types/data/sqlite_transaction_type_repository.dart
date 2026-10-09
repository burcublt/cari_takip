import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type_name.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteTransactionTypeRepository implements TransactionTypeRepository {
  SqliteTransactionTypeRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _notFound = AppException(
    AppErrorKind.notFound,
    'İşlem tipi bulunamadı.',
  );

  @override
  Future<List<TransactionType>> getTransactionTypes({
    TransactionTypeStatusFilter status = TransactionTypeStatusFilter.active,
  }) {
    return _guard(() async {
      final rows = switch (status) {
        TransactionTypeStatusFilter.all =>
          await _db.query('transaction_types'),
        TransactionTypeStatusFilter.active => await _db.query(
            'transaction_types',
            where: 'is_active = ?',
            whereArgs: [1],
          ),
        TransactionTypeStatusFilter.inactive => await _db.query(
            'transaction_types',
            where: 'is_active = ?',
            whereArgs: [0],
          ),
      };
      return rows.map(_fromRow).toList()
        ..sort((a, b) {
          final byName = compareTransactionTypeNames(a.name, b.name);
          return byName != 0 ? byName : a.id.compareTo(b.id);
        });
    });
  }

  @override
  Future<TransactionType?> getTransactionTypeById(int id) {
    return _guard(() async {
      final rows = await _db.query(
        'transaction_types',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : _fromRow(rows.first);
    });
  }

  @override
  Future<TransactionType> createTransactionType(String name) {
    return _guard(() async {
      final normalized = _validatedName(name);
      final id = await _db.transaction((txn) async {
        await _ensureUnique(txn, normalized);
        final now = AppDate.nowTimestamp(_now());
        return txn.insert('transaction_types', {
          'name': normalized,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      });
      final created = await getTransactionTypeById(id);
      return created!;
    });
  }

  @override
  Future<TransactionType> renameTransactionType(int id, String name) {
    return _guard(() async {
      final normalized = _validatedName(name);
      await _db.transaction((txn) async {
        final exists = await txn.query(
          'transaction_types',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (exists.isEmpty) throw _notFound;

        await _ensureUnique(txn, normalized, excludeId: id);
        await txn.update(
          'transaction_types',
          {'name': normalized, 'updated_at': AppDate.nowTimestamp(_now())},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      final renamed = await getTransactionTypeById(id);
      return renamed!;
    });
  }

  @override
  Future<void> setTransactionTypeActive(int id, {required bool isActive}) {
    return _guard(() async {
      final count = await _db.update(
        'transaction_types',
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': AppDate.nowTimestamp(_now()),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw _notFound;
    });
  }

  String _validatedName(String name) {
    final error = Validators.transactionTypeName(name);
    if (error != null) throw AppException(AppErrorKind.validation, error);
    return normalizeTransactionTypeName(name);
  }

  /// SQLite NOCASE yalnızca ASCII'yi kapsadığı için Türkçe duyarlı kontrol
  /// burada yapılır; veritabanı unique index'i ise son güvencedir.
  Future<void> _ensureUnique(
    DatabaseExecutor db,
    String name, {
    int? excludeId,
  }) async {
    final rows = await db.query('transaction_types', columns: ['id', 'name']);
    for (final row in rows) {
      if (row['id'] == excludeId) continue;
      if (isSameTransactionTypeName(row['name']! as String, name)) {
        throw const AppException(
          AppErrorKind.duplicate,
          duplicateTransactionTypeMessage,
        );
      }
    }
  }

  TransactionType _fromRow(Map<String, Object?> row) {
    return TransactionType(
      id: row['id']! as int,
      name: row['name']! as String,
      isActive: (row['is_active']! as int) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error, stack) {
      throw ErrorMapper.map(
        error,
        stackTrace: stack,
        duplicateMessage: duplicateTransactionTypeMessage,
      );
    }
  }
}
