import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';

/// Finans hareketi erişim sözleşmesi. Hatalar `AppException` olarak fırlatılır.
/// Sıralama her zaman `transaction_date DESC, id DESC`'tir.
abstract interface class TransactionRepository {
  Future<List<FinancialTransaction>> getTransactions({
    TransactionFilter filter = const TransactionFilter(),
    int? limit,
  });

  Future<List<FinancialTransaction>> getTransactionsByCustomer(
    int customerId, {
    int? limit,
  });

  Future<FinancialTransaction?> getTransactionById(int id);

  /// Verilen filtreye uyan kayıtların toplamı (kuruş).
  Future<int> getTransactionTotalKurus({
    TransactionFilter filter = const TransactionFilter(),
  });

  Future<FinancialTransaction> createTransaction(TransactionDraft draft);

  Future<FinancialTransaction> updateTransaction(
    int id,
    TransactionDraft draft,
  );

  /// Silme işlemi yalnızca burada yapılır (UI onay dialogunu önceden gösterir).
  Future<void> deleteTransaction(int id);
}
