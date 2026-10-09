import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/domain/customer_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_customer_repository.dart';

void main() {
  group('CustomerDraft.fromForm', () {
    test('trim eder ve boş opsiyonel alanları null yapar', () {
      final draft = CustomerDraft.fromForm(
        firstName: '  Ahmet ',
        lastName: '   ',
        phone: ' 0532 ',
        taxNumber: '',
        taxOffice: null,
        address: '  Adres  ',
        note: '\n',
      );

      expect(draft.firstName, 'Ahmet');
      expect(draft.lastName, isNull);
      expect(draft.phone, '0532');
      expect(draft.taxNumber, isNull);
      expect(draft.taxOffice, isNull);
      expect(draft.address, 'Adres');
      expect(draft.note, isNull);
    });
  });

  group('Customer.displayName', () {
    test('soyad varsa birleştirir, yoksa sadece ad/unvan', () {
      expect(makeCustomer().displayName, 'Ahmet Yılmaz');
      expect(
        makeCustomer(firstName: 'Yılmaz Ltd.', lastName: null).displayName,
        'Yılmaz Ltd.',
      );
    });
  });

  group('customerMatchesQuery', () {
    final customer = makeCustomer(
      firstName: 'İlker',
      lastName: 'Şahin',
      phone: '0532 111 22 33',
      taxNumber: '0012345678',
    );

    test('ad ve soyad (Türkçe duyarsız)', () {
      expect(customerMatchesQuery(customer, 'ilker'), isTrue);
      expect(customerMatchesQuery(customer, 'SAHIN'), isTrue);
      expect(customerMatchesQuery(customer, 'ilker şa'), isTrue);
    });

    test('telefon ve vergi no (ayraç duyarsız)', () {
      expect(customerMatchesQuery(customer, '0532'), isTrue);
      expect(customerMatchesQuery(customer, '532 111'), isTrue);
      expect(customerMatchesQuery(customer, '5321112233'), isTrue);
      expect(customerMatchesQuery(customer, '0012345'), isTrue);
    });

    test('eşleşmeyen ve boş sorgu', () {
      expect(customerMatchesQuery(customer, 'mehmet'), isFalse);
      expect(customerMatchesQuery(customer, '999'), isFalse);
      expect(customerMatchesQuery(customer, '   '), isTrue);
    });

    test('harf içeren sorguda rakam eşleşmesi yanlış pozitif üretmez', () {
      expect(customerMatchesQuery(customer, 'a1'), isFalse);
    });
  });

  test('compareCustomers Türkçe alfabetik sıralar', () {
    final list = [
      makeCustomer(id: 1, firstName: 'Zeynep', lastName: null),
      makeCustomer(id: 2, firstName: 'Çağla', lastName: null),
      makeCustomer(id: 3, firstName: 'Ali', lastName: null),
      makeCustomer(id: 4, firstName: 'İlker', lastName: null),
      makeCustomer(id: 5, firstName: 'Ömer', lastName: null),
    ]..sort(compareCustomers);

    expect(
      list.map((c) => c.firstName),
      ['Ali', 'Çağla', 'İlker', 'Ömer', 'Zeynep'],
    );
  });
}
