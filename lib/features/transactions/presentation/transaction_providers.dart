import 'package:cari_takip/core/database/database_provider.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/data/sqlite_transaction_repository.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/domain/transaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => SqliteTransactionRepository(ref.watch(appDatabaseProvider).db),
);

final transactionListProvider = FutureProvider.autoDispose
    .family<List<FinancialTransaction>, TransactionFilter>((ref, filter) {
  return ref
      .watch(transactionRepositoryProvider)
      .getTransactions(filter: filter);
});

final transactionTotalProvider =
    FutureProvider.autoDispose.family<int, TransactionFilter>((ref, filter) {
  return ref
      .watch(transactionRepositoryProvider)
      .getTransactionTotalKurus(filter: filter);
});

/// Cari detayındaki "son hareketler" kartı için.
final customerRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<FinancialTransaction>, int>((ref, customerId) {
  return ref
      .watch(transactionRepositoryProvider)
      .getTransactionsByCustomer(customerId, limit: 5);
});

/// Seçiciler için: pasifler dahil tüm cariler / tipler (geçmiş kayıtlar için).
final allCustomersProvider = FutureProvider.autoDispose<List<Customer>>((ref) {
  return ref
      .watch(customerRepositoryProvider)
      .getCustomers(status: CustomerStatusFilter.all);
});

final allTransactionTypesProvider =
    FutureProvider.autoDispose<List<TransactionType>>((ref) {
  return ref
      .watch(transactionTypeRepositoryProvider)
      .getTransactionTypes(status: TransactionTypeStatusFilter.all);
});

/// Hareket eklenince/değişince/silinince bağlı tüm okuma sonuçlarını yeniler.
void invalidateTransactionData(WidgetRef ref) {
  ref
    ..invalidate(transactionListProvider)
    ..invalidate(transactionTotalProvider)
    ..invalidate(customerRecentTransactionsProvider)
    ..invalidate(customerSummaryProvider);
}
