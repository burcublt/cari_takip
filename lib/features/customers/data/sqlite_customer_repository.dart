import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/domain/customer_repository.dart';
import 'package:cari_takip/features/customers/domain/customer_search.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteCustomerRepository implements CustomerRepository {
  SqliteCustomerRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _notFound = AppException(
    AppErrorKind.notFound,
    'Cari bulunamadı.',
  );

  @override
  Future<List<Customer>> getCustomers({
    CustomerStatusFilter status = CustomerStatusFilter.active,
  }) {
    return _guard(() async {
      final rows = switch (status) {
        CustomerStatusFilter.all => await _db.query('customers'),
        CustomerStatusFilter.active => await _db.query(
            'customers',
            where: 'is_active = ?',
            whereArgs: [1],
          ),
        CustomerStatusFilter.inactive => await _db.query(
            'customers',
            where: 'is_active = ?',
            whereArgs: [0],
          ),
      };
      return rows.map(_fromRow).toList()..sort(compareCustomers);
    });
  }

  @override
  Future<List<Customer>> searchCustomers(
    String query, {
    CustomerStatusFilter status = CustomerStatusFilter.active,
  }) async {
    final customers = await getCustomers(status: status);
    if (query.trim().isEmpty) return customers;
    return customers.where((c) => customerMatchesQuery(c, query)).toList();
  }

  @override
  Future<Customer?> getCustomerById(int id) {
    return _guard(() async {
      final rows = await _db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : _fromRow(rows.first);
    });
  }

  @override
  Future<Customer> createCustomer(CustomerDraft draft) {
    return _guard(() async {
      _validate(draft);
      final now = AppDate.nowTimestamp(_now());
      final id = await _db.insert('customers', {
        ..._draftValues(draft),
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      final created = await getCustomerById(id);
      return created!;
    });
  }

  @override
  Future<Customer> updateCustomer(int id, CustomerDraft draft) {
    return _guard(() async {
      _validate(draft);
      final count = await _db.update(
        'customers',
        {..._draftValues(draft), 'updated_at': AppDate.nowTimestamp(_now())},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) throw _notFound;
      final updated = await getCustomerById(id);
      return updated!;
    });
  }

  @override
  Future<void> setCustomerActive(int id, {required bool isActive}) {
    return _guard(() async {
      final count = await _db.update(
        'customers',
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

  @override
  Future<CustomerSummary> getCustomerSummary(int id) {
    return _guard(() async {
      final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS cnt, COALESCE(SUM(amount_kurus), 0) AS total '
        'FROM financial_transactions WHERE customer_id = ?',
        [id],
      );
      return CustomerSummary(
        transactionCount: rows.first['cnt']! as int,
        totalKurus: rows.first['total']! as int,
      );
    });
  }

  void _validate(CustomerDraft draft) {
    final error = Validators.customerName(draft.firstName);
    if (error != null) throw AppException(AppErrorKind.validation, error);
  }

  Map<String, Object?> _draftValues(CustomerDraft draft) => {
        'first_name': draft.firstName.trim(),
        'last_name': draft.lastName,
        'phone': draft.phone,
        'tax_number': draft.taxNumber,
        'tax_office': draft.taxOffice,
        'address': draft.address,
        'note': draft.note,
        'accounting_fee_kurus': draft.accountingFeeKurus,
      };

  Customer _fromRow(Map<String, Object?> row) {
    return Customer(
      id: row['id']! as int,
      firstName: row['first_name']! as String,
      lastName: row['last_name'] as String?,
      phone: row['phone'] as String?,
      taxNumber: row['tax_number'] as String?,
      taxOffice: row['tax_office'] as String?,
      address: row['address'] as String?,
      note: row['note'] as String?,
      accountingFeeKurus: row['accounting_fee_kurus'] as int?,
      isActive: (row['is_active']! as int) == 1,
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
