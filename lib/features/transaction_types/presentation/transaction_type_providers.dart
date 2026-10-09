import 'package:cari_takip/core/database/database_provider.dart';
import 'package:cari_takip/features/transaction_types/data/sqlite_transaction_type_repository.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transactionTypeRepositoryProvider = Provider<TransactionTypeRepository>(
  (ref) => SqliteTransactionTypeRepository(ref.watch(appDatabaseProvider).db),
);

class TransactionTypeStatusFilterNotifier
    extends Notifier<TransactionTypeStatusFilter> {
  @override
  TransactionTypeStatusFilter build() => TransactionTypeStatusFilter.active;

  void setStatus(TransactionTypeStatusFilter status) => state = status;
}

final transactionTypeStatusFilterProvider = NotifierProvider<
    TransactionTypeStatusFilterNotifier, TransactionTypeStatusFilter>(
  TransactionTypeStatusFilterNotifier.new,
);

final transactionTypeListProvider =
    FutureProvider.autoDispose<List<TransactionType>>((ref) {
  final status = ref.watch(transactionTypeStatusFilterProvider);
  return ref
      .watch(transactionTypeRepositoryProvider)
      .getTransactionTypes(status: status);
});
