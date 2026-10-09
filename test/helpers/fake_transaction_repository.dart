import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/domain/transaction_repository.dart';

import 'fake_customer_repository.dart';
import 'fake_transaction_type_repository.dart';

FinancialTransaction makeTransaction({
  int id = 1,
  int customerId = 1,
  String customerName = 'Ahmet Yılmaz',
  int transactionTypeId = 1,
  String transactionTypeName = 'Kira',
  DateTime? date,
  int amountKurus = 125050,
  String? note,
}) {
  return FinancialTransaction(
    id: id,
    customerId: customerId,
    customerName: customerName,
    transactionTypeId: transactionTypeId,
    transactionTypeName: transactionTypeName,
    transactionDate: date ?? DateTime(2026, 9, 15),
    amountKurus: amountKurus,
    note: note,
    createdAt: DateTime.utc(2026, 9, 29),
    updatedAt: DateTime.utc(2026, 9, 29),
  );
}

/// Bellekte çalışan sahte repository. Cari/tip adlarını diğer sahte
/// repository'lerden çözer.
class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository({
    required this.customers,
    required this.types,
    List<FinancialTransaction>? initial,
  }) : transactions = [...?initial];

  final FakeCustomerRepository customers;
  final FakeTransactionTypeRepository types;
  final List<FinancialTransaction> transactions;

  int get _nextId =>
      transactions.fold(0, (max, t) => t.id > max ? t.id : max) + 1;

  bool _matches(FinancialTransaction t, TransactionFilter f) {
    if (f.customerId != null && t.customerId != f.customerId) return false;
    if (f.transactionTypeId != null &&
        t.transactionTypeId != f.transactionTypeId) {
      return false;
    }
    if (f.fromDate != null && t.transactionDate.isBefore(f.fromDate!)) {
      return false;
    }
    if (f.toDate != null && t.transactionDate.isAfter(f.toDate!)) {
      return false;
    }
    return true;
  }

  FinancialTransaction _build(int id, TransactionDraft d) {
    final customer = customers.customers.firstWhere((c) => c.id == d.customerId);
    final type = types.types.firstWhere((t) => t.id == d.transactionTypeId);
    final note = d.note?.trim();
    return makeTransaction(
      id: id,
      customerId: customer.id,
      customerName: customer.displayName,
      transactionTypeId: type.id,
      transactionTypeName: type.name,
      date: d.transactionDate,
      amountKurus: d.amountKurus,
      note: note == null || note.isEmpty ? null : note,
    );
  }

  @override
  Future<List<FinancialTransaction>> getTransactions({
    TransactionFilter filter = const TransactionFilter(),
    int? limit,
  }) async {
    final list = transactions.where((t) => _matches(t, filter)).toList()
      ..sort((a, b) {
        final byDate = b.transactionDate.compareTo(a.transactionDate);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return limit == null ? list : list.take(limit).toList();
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
  Future<FinancialTransaction?> getTransactionById(int id) async {
    for (final t in transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<int> getTransactionTotalKurus({
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    return transactions
        .where((t) => _matches(t, filter))
        .fold<int>(0, (sum, t) => sum + t.amountKurus);
  }

  @override
  Future<FinancialTransaction> createTransaction(TransactionDraft draft) async {
    final created = _build(_nextId, draft);
    transactions.add(created);
    return created;
  }

  @override
  Future<FinancialTransaction> updateTransaction(
    int id,
    TransactionDraft draft,
  ) async {
    final index = transactions.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw const AppException(
        AppErrorKind.notFound,
        'Finans hareketi bulunamadı.',
      );
    }
    final updated = _build(id, draft);
    transactions[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final before = transactions.length;
    transactions.removeWhere((t) => t.id == id);
    if (transactions.length == before) {
      throw const AppException(
        AppErrorKind.notFound,
        'Finans hareketi bulunamadı.',
      );
    }
  }
}
