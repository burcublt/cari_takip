import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/domain/customer_repository.dart';
import 'package:cari_takip/features/customers/domain/customer_search.dart';

Customer makeCustomer({
  int id = 1,
  String firstName = 'Ahmet',
  String? lastName = 'Yılmaz',
  String? phone = '0532 111 22 33',
  String? taxNumber = '1234567890',
  bool isActive = true,
}) {
  return Customer(
    id: id,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    taxNumber: taxNumber,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 9, 29),
    updatedAt: DateTime.utc(2026, 9, 29),
  );
}

/// Bellekte çalışan sahte repository (widget testleri için).
class FakeCustomerRepository implements CustomerRepository {
  FakeCustomerRepository([List<Customer>? initial])
      : customers = [...?initial];

  final List<Customer> customers;
  CustomerSummary summary =
      const CustomerSummary(transactionCount: 0, totalKurus: 0);

  int get _nextId =>
      customers.fold(0, (max, c) => c.id > max ? c.id : max) + 1;

  bool _matches(Customer c, CustomerStatusFilter status) => switch (status) {
        CustomerStatusFilter.all => true,
        CustomerStatusFilter.active => c.isActive,
        CustomerStatusFilter.inactive => !c.isActive,
      };

  @override
  Future<List<Customer>> getCustomers({
    CustomerStatusFilter status = CustomerStatusFilter.active,
  }) async {
    return customers.where((c) => _matches(c, status)).toList()
      ..sort(compareCustomers);
  }

  @override
  Future<List<Customer>> searchCustomers(
    String query, {
    CustomerStatusFilter status = CustomerStatusFilter.active,
  }) async {
    final all = await getCustomers(status: status);
    return all.where((c) => customerMatchesQuery(c, query)).toList();
  }

  @override
  Future<Customer?> getCustomerById(int id) async {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Customer _build(int id, CustomerDraft d, {required bool isActive}) {
    return Customer(
      id: id,
      firstName: d.firstName,
      lastName: d.lastName,
      phone: d.phone,
      taxNumber: d.taxNumber,
      taxOffice: d.taxOffice,
      address: d.address,
      note: d.note,
      isActive: isActive,
      createdAt: DateTime.utc(2026, 9, 29),
      updatedAt: DateTime.utc(2026, 9, 30),
    );
  }

  @override
  Future<Customer> createCustomer(CustomerDraft draft) async {
    final created = _build(_nextId, draft, isActive: true);
    customers.add(created);
    return created;
  }

  @override
  Future<Customer> updateCustomer(int id, CustomerDraft draft) async {
    final index = customers.indexWhere((c) => c.id == id);
    if (index < 0) {
      throw const AppException(AppErrorKind.notFound, 'Cari bulunamadı.');
    }
    final updated =
        _build(id, draft, isActive: customers[index].isActive);
    customers[index] = updated;
    return updated;
  }

  @override
  Future<void> setCustomerActive(int id, {required bool isActive}) async {
    final index = customers.indexWhere((c) => c.id == id);
    if (index < 0) {
      throw const AppException(AppErrorKind.notFound, 'Cari bulunamadı.');
    }
    final c = customers[index];
    customers[index] = Customer(
      id: c.id,
      firstName: c.firstName,
      lastName: c.lastName,
      phone: c.phone,
      taxNumber: c.taxNumber,
      taxOffice: c.taxOffice,
      address: c.address,
      note: c.note,
      isActive: isActive,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
  }

  @override
  Future<CustomerSummary> getCustomerSummary(int id) async => summary;
}
