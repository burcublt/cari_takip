import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/transactions/data/sqlite_transaction_repository.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher _appError(AppErrorKind kind) =>
    isA<AppException>().having((e) => e.kind, 'kind', kind);

// Seed tip id'leri: Borç=1, Kira=2, Fatura=3, Vergi=4, Muhasebe Ücreti=5, Sigorta=6
const _borc = 1;
const _kira = 2;
const _fatura = 3;

void main() {
  late AppDatabase appDb;
  late SqliteTransactionRepository repo;
  late int ali;
  late int veli;
  var clock = DateTime.utc(2026, 9, 29, 10);

  setUpAll(sqfliteFfiInit);

  Future<int> addCustomer(String first, {String? last}) {
    return appDb.db.insert('customers', {
      'first_name': first,
      'last_name': last,
      'is_active': 1,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  setUp(() async {
    clock = DateTime.utc(2026, 9, 29, 10);
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = SqliteTransactionRepository(appDb.db, now: () => clock);
    ali = await addCustomer('Ahmet', last: 'Yılmaz');
    veli = await addCustomer('Veli Ltd.');
  });

  tearDown(() => appDb.close());

  TransactionDraft draft({
    int? customerId,
    int typeId = _kira,
    TransactionDirection direction = TransactionDirection.debt,
    DateTime? date,
    int amount = 125050,
    String? note,
  }) {
    return TransactionDraft(
      customerId: customerId ?? ali,
      transactionTypeId: typeId,
      direction: direction,
      transactionDate: date ?? DateTime(2026, 9, 15),
      amountKurus: amount,
      note: note,
    );
  }

  group('createTransaction', () {
    test('kaydeder, adları birleştirir, tarihi YYYY-MM-DD saklar', () async {
      final created = await repo.createTransaction(
        draft(note: '  Eylül kirası  '),
      );

      expect(created.id, isPositive);
      expect(created.customerName, 'Ahmet Yılmaz');
      expect(created.transactionTypeName, 'Kira');
      expect(created.direction, TransactionDirection.debt);
      expect(created.transactionDate, DateTime(2026, 9, 15));
      expect(created.amountKurus, 125050);
      expect(created.note, 'Eylül kirası');
      expect(created.createdAt, clock);
      expect(created.updatedAt, clock);

      final raw = await appDb.db.query('financial_transactions');
      expect(raw.single['transaction_date'], '2026-09-15');
      expect(raw.single['amount_kurus'], 125050);
      expect(raw.single['direction'], 'debt');
    });

    test('tahsilat yönünü saklar ve yeniden yükler', () async {
      final created = await repo.createTransaction(
        draft(direction: TransactionDirection.collection),
      );

      expect(created.direction, TransactionDirection.collection);
      expect(
        (await repo.getTransactionById(created.id))!.direction,
        TransactionDirection.collection,
      );
    });

    test('boş not null saklanır; soyadı olmayan cari tek ad gösterilir',
        () async {
      final created = await repo.createTransaction(
        draft(customerId: veli, note: '   '),
      );
      expect(created.note, isNull);
      expect(created.customerName, 'Veli Ltd.');
    });

    test('sıfır ve negatif tutar reddedilir, kayıt eklenmez', () async {
      for (final amount in [0, -100]) {
        await expectLater(
          repo.createTransaction(draft(amount: amount)),
          throwsA(_appError(AppErrorKind.validation)),
        );
      }
      expect(await repo.getTransactions(), isEmpty);
    });

    test('olmayan cari veya tip reddedilir', () async {
      await expectLater(
        repo.createTransaction(draft(customerId: 999)),
        throwsA(_appError(AppErrorKind.validation)),
      );
      await expectLater(
        repo.createTransaction(draft(typeId: 999)),
        throwsA(_appError(AppErrorKind.validation)),
      );
      expect(await repo.getTransactions(), isEmpty);
    });
  });

  group('listeleme ve filtreler', () {
    setUp(() async {
      await repo.createTransaction(
        draft(date: DateTime(2026, 9), amount: 100000, note: 'a'),
      );
      await repo.createTransaction(
        draft(date: DateTime(2026, 9, 15), amount: 50000, note: 'b'),
      );
      await repo.createTransaction(
        draft(
          date: DateTime(2026, 9, 15),
          amount: 25000,
          typeId: _fatura,
          note: 'c',
        ),
      );
      await repo.createTransaction(
        draft(
          customerId: veli,
          date: DateTime(2026, 10),
          amount: 7550,
          typeId: _borc,
          direction: TransactionDirection.collection,
          note: 'd',
        ),
      );
    });

    test('tarih azalan, aynı tarihte id azalan sıralanır', () async {
      final notes = (await repo.getTransactions()).map((t) => t.note);
      expect(notes, ['d', 'c', 'b', 'a']);
    });

    test('cariye göre süzer', () async {
      final list = await repo.getTransactions(
        filter: TransactionFilter(customerId: veli),
      );
      expect(list.single.note, 'd');
    });

    test('tipe göre süzer', () async {
      final list = await repo.getTransactions(
        filter: const TransactionFilter(transactionTypeId: _fatura),
      );
      expect(list.single.note, 'c');
    });

    test('tarih aralığı sınırlar dahil süzer', () async {
      final list = await repo.getTransactions(
        filter: TransactionFilter(
          fromDate: DateTime(2026, 9, 15),
          toDate: DateTime(2026, 9, 15),
        ),
      );
      expect(list.map((t) => t.note), ['c', 'b']);

      final onlyFrom = await repo.getTransactions(
        filter: TransactionFilter(fromDate: DateTime(2026, 10)),
      );
      expect(onlyFrom.map((t) => t.note), ['d']);

      final onlyTo = await repo.getTransactions(
        filter: TransactionFilter(toDate: DateTime(2026, 9)),
      );
      expect(onlyTo.map((t) => t.note), ['a']);
    });

    test('filtreler birlikte uygulanır', () async {
      final list = await repo.getTransactions(
        filter: TransactionFilter(
          customerId: ali,
          transactionTypeId: _kira,
          fromDate: DateTime(2026, 9, 10),
        ),
      );
      expect(list.single.note, 'b');
    });

    test('toplam yalnızca filtreye uyan kayıtları kuruş olarak toplar',
        () async {
      expect(await repo.getTransactionTotalKurus(), -167450);
      expect(
        await repo.getTransactionTotalKurus(
          filter: TransactionFilter(customerId: ali),
        ),
        -175000,
      );
      expect(
        await repo.getTransactionTotalKurus(
          filter: TransactionFilter(
            customerId: ali,
            fromDate: DateTime(2026, 9, 15),
          ),
        ),
        -75000,
      );
    });

    test('eşleşme yoksa toplam sıfırdır', () async {
      expect(
        await repo.getTransactionTotalKurus(
          filter: const TransactionFilter(transactionTypeId: 6),
        ),
        0,
      );
    });

    test('getTransactionsByCustomer limit uygular', () async {
      final list = await repo.getTransactionsByCustomer(ali, limit: 2);
      expect(list.map((t) => t.note), ['c', 'b']);
    });

    test('pasif cari ve pasif tipin geçmiş hareketleri listelenmeye devam eder',
        () async {
      await appDb.db.update('customers', {'is_active': 0});
      await appDb.db.update('transaction_types', {'is_active': 0});

      expect(await repo.getTransactions(), hasLength(4));
    });
  });

  group('updateTransaction', () {
    test('tüm alanları günceller; createdAt korunur, updatedAt yenilenir',
        () async {
      final created = await repo.createTransaction(draft(note: 'eski'));

      clock = DateTime.utc(2026, 10, 1, 9);
      final updated = await repo.updateTransaction(
        created.id,
        draft(
          customerId: veli,
          typeId: _fatura,
          direction: TransactionDirection.collection,
          date: DateTime(2026, 9, 20),
          amount: 99,
          note: ' yeni ',
        ),
      );

      expect(updated.id, created.id);
      expect(updated.customerName, 'Veli Ltd.');
      expect(updated.transactionTypeName, 'Fatura');
      expect(updated.direction, TransactionDirection.collection);
      expect(updated.transactionDate, DateTime(2026, 9, 20));
      expect(updated.amountKurus, 99);
      expect(updated.note, 'yeni');
      expect(updated.createdAt, DateTime.utc(2026, 9, 29, 10));
      expect(updated.updatedAt, DateTime.utc(2026, 10, 1, 9));
    });

    test('geçersiz tutar reddedilir ve kayıt değişmez', () async {
      final created = await repo.createTransaction(draft());
      await expectLater(
        repo.updateTransaction(created.id, draft(amount: 0)),
        throwsA(_appError(AppErrorKind.validation)),
      );
      expect((await repo.getTransactionById(created.id))!.amountKurus, 125050);
    });

    test('olmayan kayıt notFound verir', () async {
      await expectLater(
        repo.updateTransaction(999, draft()),
        throwsA(_appError(AppErrorKind.notFound)),
      );
    });

    test('pasife alınmış cari ve tipin eski hareketi düzenlenebilir', () async {
      final created = await repo.createTransaction(draft());
      await appDb.db.update('customers', {'is_active': 0});
      await appDb.db.update('transaction_types', {'is_active': 0});

      final updated = await repo.updateTransaction(
        created.id,
        draft(amount: 200),
      );
      expect(updated.amountKurus, 200);
    });
  });

  group('deleteTransaction', () {
    test('kaydı siler, diğerlerine dokunmaz', () async {
      final a = await repo.createTransaction(draft(note: 'a'));
      final b = await repo.createTransaction(draft(note: 'b'));

      await repo.deleteTransaction(a.id);

      expect(await repo.getTransactionById(a.id), isNull);
      expect(await repo.getTransactionById(b.id), isNotNull);
    });

    test('olmayan kayıt notFound verir', () async {
      await expectLater(
        repo.deleteTransaction(999),
        throwsA(_appError(AppErrorKind.notFound)),
      );
    });
  });

  test('getTransactionById olmayan kayıt için null döner', () async {
    expect(await repo.getTransactionById(999), isNull);
  });
}
