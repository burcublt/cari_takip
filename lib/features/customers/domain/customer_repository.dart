import 'package:cari_takip/features/customers/domain/customer.dart';

/// Cari erişim sözleşmesi. Hatalar `AppException` olarak fırlatılır.
abstract interface class CustomerRepository {
  Future<List<Customer>> getCustomers({
    CustomerStatusFilter status = CustomerStatusFilter.active,
  });

  Future<List<Customer>> searchCustomers(
    String query, {
    CustomerStatusFilter status = CustomerStatusFilter.active,
  });

  Future<Customer?> getCustomerById(int id);

  Future<Customer> createCustomer(CustomerDraft draft);

  Future<Customer> updateCustomer(int id, CustomerDraft draft);

  /// Cariler silinmez; yalnızca aktif/pasif yapılır.
  Future<void> setCustomerActive(int id, {required bool isActive});

  Future<CustomerSummary> getCustomerSummary(int id);
}
