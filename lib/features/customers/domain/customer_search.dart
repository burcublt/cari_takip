import 'package:cari_takip/core/utils/text_search.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';

/// Ad, soyad, telefon ve vergi numarasında arar.
/// Metin araması Türkçe/aksan duyarsızdır; rakamla yapılan aramada telefon ve
/// vergi numarası boşluk/ayraç farkı gözetilmeden eşleştirilir.
bool customerMatchesQuery(Customer customer, String query) {
  final q = TextSearch.key(query);
  if (q.isEmpty) return true;

  final textFields = [
    customer.firstName,
    customer.lastName,
    customer.displayName,
    customer.phone,
    customer.taxNumber,
  ];
  for (final field in textFields) {
    if (field != null && TextSearch.key(field).contains(q)) return true;
  }

  if (TextSearch.isPhoneLike(query)) {
    final queryDigits = TextSearch.digits(query);
    if (queryDigits.isNotEmpty) {
      for (final field in [customer.phone, customer.taxNumber]) {
        if (field != null && TextSearch.digits(field).contains(queryDigits)) {
          return true;
        }
      }
    }
  }
  return false;
}

/// Türkçe alfabetik sıralama (aksan duyarsız), eşitlikte id.
int compareCustomers(Customer a, Customer b) {
  final byName = TextSearch.key(a.displayName)
      .compareTo(TextSearch.key(b.displayName));
  return byName != 0 ? byName : a.id.compareTo(b.id);
}
