import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/customers/data/sqlite_customer_repository.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher _appError(AppErrorKind kind) =>
    isA<AppException>().having((e) => e.kind, 'kind', kind);

void main() {
  late AppDatabase appDb;
  late SqliteCustomerRepository repo;
  var clock = DateTime.utc(2026, 9, 29, 10);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    clock = DateTime.utc(2026, 9, 29, 10);
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = SqliteCustomerRepository(appDb.db, now: () => clock);
  });

  tearDown(() => appDb.close());

  Future<Customer> create(
    String firstName, {
    String? lastName,
    String? phone,
    String? taxNumber,
  }) {
    return repo.createCustomer(
      CustomerDraft.fromForm(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        taxNumber: taxNumber,
      ),
    );
  }

  Future<void> addTransaction(int customerId, int kurus) {
    return appDb.db.insert('financial_transactions', {
      'customer_id': customerId,
      'transaction_type_id': 1,
      'transaction_date': '2026-09-29',
      'amount_kurus': kurus,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  group('createCustomer', () {
    test('kaydeder, trim eder, boş alanları null bırakır, aktif başlatır',
        () async {
      final created = await repo.createCustomer(
        CustomerDraft.fromForm(
          firstName: '  Ahmet ',
          lastName: '   ',
          phone: ' 0532 ',
        ),
      );

      expect(created.id, isPositive);
      expect(created.firstName, 'Ahmet');
      expect(created.lastName, isNull);
      expect(created.phone, '0532');
      expect(created.isActive, isTrue);
      expect(created.createdAt, clock);
      expect(created.updatedAt, clock);
    });

    test('vergi numarası metin olarak saklanır (baştaki sıfır korunur)',
        () async {
      final created = await create('Firma', taxNumber: '0123456789');
      final loaded = await repo.getCustomerById(created.id);
      expect(loaded!.taxNumber, '0123456789');
    });

    test('boş ad reddedilir', () async {
      await expectLater(
        repo.createCustomer(const CustomerDraft(firstName: '   ')),
        throwsA(_appError(AppErrorKind.validation)),
      );
      expect(await repo.getCustomers(status: CustomerStatusFilter.all), isEmpty);
    });
  });

  group('listeleme', () {
    test('varsayılan yalnızca aktif carileri getirir', () async {
      final a = await create('Ali');
      final b = await create('Veli');
      await repo.setCustomerActive(b.id, isActive: false);

      final active = await repo.getCustomers();
      final inactive = await repo.getCustomers(
        status: CustomerStatusFilter.inactive,
      );
      final all = await repo.getCustomers(status: CustomerStatusFilter.all);

      expect(active.map((c) => c.id), [a.id]);
      expect(inactive.map((c) => c.id), [b.id]);
      expect(all, hasLength(2));
    });

    test('Türkçe alfabetik sıralar', () async {
      for (final name in ['Zeynep', 'Çağla', 'Ali', 'İlker', 'Ömer']) {
        await create(name);
      }
      final names = (await repo.getCustomers()).map((c) => c.firstName);
      expect(names, ['Ali', 'Çağla', 'İlker', 'Ömer', 'Zeynep']);
    });

    test('getCustomerById olmayan kayıt için null döner', () async {
      expect(await repo.getCustomerById(999), isNull);
    });
  });

  group('arama', () {
    setUp(() async {
      await create('İlker', lastName: 'Şahin', phone: '0532 111 22 33');
      await create('Yılmaz Ltd.', taxNumber: '9876543210');
      final passive = await create('Pasif Firma');
      await repo.setCustomerActive(passive.id, isActive: false);
    });

    test('ad, soyad, telefon ve vergi no ile bulur', () async {
      expect((await repo.searchCustomers('ilker')).single.firstName, 'İlker');
      expect((await repo.searchCustomers('sahin')).single.firstName, 'İlker');
      expect((await repo.searchCustomers('532 111')).single.firstName, 'İlker');
      expect(
        (await repo.searchCustomers('98765')).single.firstName,
        'Yılmaz Ltd.',
      );
    });

    test('boş sorgu tüm listeyi, eşleşmeyen sorgu boş liste döner', () async {
      expect(await repo.searchCustomers('  '), hasLength(2));
      expect(await repo.searchCustomers('bulunmaz'), isEmpty);
    });

    test('durum filtresine uyar', () async {
      expect(await repo.searchCustomers('pasif'), isEmpty);
      final found = await repo.searchCustomers(
        'pasif',
        status: CustomerStatusFilter.inactive,
      );
      expect(found.single.firstName, 'Pasif Firma');
    });
  });

  group('updateCustomer', () {
    test('alanları günceller; createdAt ve aktiflik durumu korunur', () async {
      final created = await create('Ali', phone: '111');
      await repo.setCustomerActive(created.id, isActive: false);

      clock = DateTime.utc(2026, 10, 1, 9);
      final updated = await repo.updateCustomer(
        created.id,
        CustomerDraft.fromForm(firstName: ' Ali Veli ', phone: ''),
      );

      expect(updated.firstName, 'Ali Veli');
      expect(updated.phone, isNull);
      expect(updated.isActive, isFalse);
      expect(updated.createdAt, DateTime.utc(2026, 9, 29, 10));
      expect(updated.updatedAt, DateTime.utc(2026, 10, 1, 9));
    });

    test('olmayan cari notFound fırlatır', () async {
      await expectLater(
        repo.updateCustomer(999, const CustomerDraft(firstName: 'X')),
        throwsA(_appError(AppErrorKind.notFound)),
      );
    });

    test('boş ad ile güncelleme reddedilir', () async {
      final created = await create('Ali');
      await expectLater(
        repo.updateCustomer(created.id, const CustomerDraft(firstName: ' ')),
        throwsA(_appError(AppErrorKind.validation)),
      );
      expect((await repo.getCustomerById(created.id))!.firstName, 'Ali');
    });
  });

  group('setCustomerActive', () {
    test('pasife alır ve tekrar aktif eder', () async {
      final created = await create('Ali');

      await repo.setCustomerActive(created.id, isActive: false);
      expect((await repo.getCustomerById(created.id))!.isActive, isFalse);

      await repo.setCustomerActive(created.id, isActive: true);
      expect((await repo.getCustomerById(created.id))!.isActive, isTrue);
    });

    test('olmayan cari notFound fırlatır', () async {
      await expectLater(
        repo.setCustomerActive(999, isActive: false),
        throwsA(_appError(AppErrorKind.notFound)),
      );
    });

    test('pasife almak finans geçmişini korur', () async {
      final created = await create('Ali');
      await addTransaction(created.id, 125050);

      await repo.setCustomerActive(created.id, isActive: false);

      expect(await repo.getCustomerById(created.id), isNotNull);
      final summary = await repo.getCustomerSummary(created.id);
      expect(summary.transactionCount, 1);
      expect(summary.totalKurus, 125050);
    });
  });

  group('getCustomerSummary', () {
    test('hareket yoksa sıfır döner', () async {
      final created = await create('Ali');
      final summary = await repo.getCustomerSummary(created.id);
      expect(summary.transactionCount, 0);
      expect(summary.totalKurus, 0);
    });

    test('yalnızca ilgili carinin hareketlerini toplar (kuruş)', () async {
      final ali = await create('Ali');
      final veli = await create('Veli');
      await addTransaction(ali.id, 125050);
      await addTransaction(ali.id, 100);
      await addTransaction(veli.id, 999);

      final summary = await repo.getCustomerSummary(ali.id);
      expect(summary.transactionCount, 2);
      expect(summary.totalKurus, 125150);
    });
  });
}
