import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/reports/data/sqlite_report_repository.dart';
import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher _appError(AppErrorKind kind) =>
    isA<AppException>().having((e) => e.kind, 'kind', kind);

// Seed tip id'leri: Borç=1, Kira=2, Fatura=3, Vergi=4
const _borc = 1;
const _kira = 2;
const _fatura = 3;

void main() {
  late AppDatabase appDb;
  late SqliteReportRepository repo;
  late int ali;
  late int veli;

  setUpAll(sqfliteFfiInit);

  Future<int> addCustomer(String first, {String? last, bool active = true}) {
    return appDb.db.insert('customers', {
      'first_name': first,
      'last_name': last,
      'is_active': active ? 1 : 0,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  Future<int> addTx(
    int customerId,
    int typeId,
    String date,
    int kurus, {
    String? note,
  }) {
    return appDb.db.insert('financial_transactions', {
      'customer_id': customerId,
      'transaction_type_id': typeId,
      'transaction_date': date,
      'amount_kurus': kurus,
      'note': note,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  setUp(() async {
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = SqliteReportRepository(appDb.db);
    ali = await addCustomer('Ahmet', last: 'Yılmaz');
    veli = await addCustomer('Veli Ltd.');

    await addTx(ali, _kira, '2026-09-01', 100000, note: 'a');
    await addTx(ali, _kira, '2026-09-15', 50000, note: 'b');
    await addTx(ali, _fatura, '2026-09-15', 25000, note: 'c');
    await addTx(ali, _borc, '2026-10-01', 10, note: 'd');
    await addTx(veli, _kira, '2026-09-15', 999999, note: 'veli');
  });

  tearDown(() => appDb.close());

  test('yalnızca seçilen carinin hareketlerini ve toplamını verir', () async {
    final result = await repo.getReport(ReportFilter(customerId: ali));

    expect(result.customerName, 'Ahmet Yılmaz');
    expect(result.rows.map((r) => r.note), ['d', 'c', 'b', 'a']);
    expect(result.count, 4);
    expect(result.totalKurus, 175010);
    expect(result.filter, ReportFilter(customerId: ali));
  });

  test('satır alanları doğru eşlenir', () async {
    final result = await repo.getReport(
      const ReportFilter(customerId: 1, transactionTypeId: _fatura),
    );

    final row = result.rows.single;
    expect(row.transactionDate, DateTime(2026, 9, 15));
    expect(row.transactionTypeName, 'Fatura');
    expect(row.amountKurus, 25000);
    expect(row.note, 'c');
  });

  test('sıralama tarih azalan, aynı tarihte id azalan', () async {
    final ids = (await repo.getReport(ReportFilter(customerId: ali)))
        .rows
        .map((r) => r.id)
        .toList();
    // b(id 2) ve c(id 3) aynı tarihte: c önce gelir.
    expect(ids, [4, 3, 2, 1]);
  });

  test('tarih aralığı uçlar dahil süzer; toplam yalnızca bu kayıtlardır',
      () async {
    final result = await repo.getReport(
      ReportFilter(
        customerId: ali,
        fromDate: DateTime(2026, 9, 15),
        toDate: DateTime(2026, 9, 15),
      ),
    );
    expect(result.rows.map((r) => r.note), ['c', 'b']);
    expect(result.totalKurus, 75000);

    final onlyFrom = await repo.getReport(
      ReportFilter(customerId: ali, fromDate: DateTime(2026, 10)),
    );
    expect(onlyFrom.rows.map((r) => r.note), ['d']);
    expect(onlyFrom.totalKurus, 10);

    final onlyTo = await repo.getReport(
      ReportFilter(customerId: ali, toDate: DateTime(2026, 9)),
    );
    expect(onlyTo.rows.map((r) => r.note), ['a']);
    expect(onlyTo.totalKurus, 100000);
  });

  test('işlem tipi filtresi çalışır, seçilmezse tüm tipler dahildir',
      () async {
    final kira = await repo.getReport(
      const ReportFilter(customerId: 1, transactionTypeId: _kira),
    );
    expect(kira.rows.map((r) => r.note), ['b', 'a']);
    expect(kira.totalKurus, 150000);

    final all = await repo.getReport(ReportFilter(customerId: ali));
    expect(all.count, 4);
  });

  test('tarih ve tip filtreleri birlikte uygulanır', () async {
    final result = await repo.getReport(
      ReportFilter(
        customerId: ali,
        transactionTypeId: _kira,
        fromDate: DateTime(2026, 9, 10),
      ),
    );
    expect(result.rows.single.note, 'b');
    expect(result.totalKurus, 50000);
  });

  test('eşleşme yoksa satır boş, toplam sıfırdır', () async {
    final result = await repo.getReport(
      ReportFilter(
        customerId: ali,
        fromDate: DateTime(2027),
      ),
    );
    expect(result.rows, isEmpty);
    expect(result.totalKurus, 0);
  });

  test('hareketi olmayan cari için boş rapor döner', () async {
    final empty = await addCustomer('Boş');
    final result = await repo.getReport(ReportFilter(customerId: empty));
    expect(result.rows, isEmpty);
    expect(result.totalKurus, 0);
  });

  test('toplam kuruş hassasiyetini korur (ondalık hata yok)', () async {
    final c = await addCustomer('Kuruş');
    await addTx(c, _kira, '2026-09-01', 10); // 0,10
    await addTx(c, _kira, '2026-09-02', 20); // 0,20
    final result = await repo.getReport(ReportFilter(customerId: c));
    expect(result.totalKurus, 30);
  });

  test('çok büyük tutarlar taşmadan toplanır', () async {
    final c = await addCustomer('Büyük');
    await addTx(c, _kira, '2026-09-01', 999999999999900);
    await addTx(c, _kira, '2026-09-02', 100);
    final result = await repo.getReport(ReportFilter(customerId: c));
    expect(result.totalKurus, 1000000000000000);
  });

  test('pasif cari ve pasif tipin geçmişi raporlanır', () async {
    await appDb.db.update('customers', {'is_active': 0});
    await appDb.db.update('transaction_types', {'is_active': 0});

    final result = await repo.getReport(ReportFilter(customerId: ali));
    expect(result.count, 4);
  });

  test('başlangıç bitişten sonraysa doğrulama hatası verir', () async {
    await expectLater(
      repo.getReport(
        ReportFilter(
          customerId: ali,
          fromDate: DateTime(2026, 10),
          toDate: DateTime(2026, 9),
        ),
      ),
      throwsA(_appError(AppErrorKind.validation)),
    );
  });

  test('olmayan cari notFound verir', () async {
    await expectLater(
      repo.getReport(const ReportFilter(customerId: 999)),
      throwsA(_appError(AppErrorKind.notFound)),
    );
  });
}
