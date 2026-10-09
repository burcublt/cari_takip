import 'package:cari_takip/core/database/database_provider.dart';
import 'package:cari_takip/features/customers/data/sqlite_customer_repository.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/domain/customer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => SqliteCustomerRepository(ref.watch(appDatabaseProvider).db),
);

class CustomerListFilter {
  const CustomerListFilter({
    this.query = '',
    this.status = CustomerStatusFilter.active,
  });

  final String query;
  final CustomerStatusFilter status;

  CustomerListFilter copyWith({String? query, CustomerStatusFilter? status}) {
    return CustomerListFilter(
      query: query ?? this.query,
      status: status ?? this.status,
    );
  }
}

class CustomerListFilterNotifier extends Notifier<CustomerListFilter> {
  @override
  CustomerListFilter build() => const CustomerListFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setStatus(CustomerStatusFilter status) =>
      state = state.copyWith(status: status);
}

final customerListFilterProvider =
    NotifierProvider<CustomerListFilterNotifier, CustomerListFilter>(
  CustomerListFilterNotifier.new,
);

final customerListProvider = FutureProvider.autoDispose<List<Customer>>((ref) {
  final filter = ref.watch(customerListFilterProvider);
  return ref
      .watch(customerRepositoryProvider)
      .searchCustomers(filter.query, status: filter.status);
});

final customerDetailProvider =
    FutureProvider.autoDispose.family<Customer?, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).getCustomerById(id);
});

final customerSummaryProvider =
    FutureProvider.autoDispose.family<CustomerSummary, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).getCustomerSummary(id);
});
