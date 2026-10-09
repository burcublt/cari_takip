import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/features/dashboard/data/sqlite_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Seed tip id'leri: Borç=1, Kira=2, Fatura=3
const _borc = 1;
const _kira = 2;
const _fatura = 3;

void main() {
  late AppDatabase appDb;
  late SqliteDashboardRepository repo;

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

  Future<int> addTx(int customerId, int typeId, String date, int kurus) {
    return appDb.db.insert('financial_transactions', {
      'customer_id': customerId,
      'transaction_type_id': typeId,
      'transaction_date': date,
      'amount_kurus': kurus,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  setUp(() async {
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    // "Bugün" 15 Eylül 2026 (saat bilgisi ay hesabını etkilememeli).
    repo = SqliteDashboardRepository(
      appDb.db,
      now: () => DateTime(2026, 9, 15, 23, 59),
    );
  });

  tearDown(() => appDb.close());

  test('boş veritabanında tüm değerler sıfırdır', () async {
    final summary = await repo.getSummary();

    expect(summary.activeCustomerCount, 0);
    expect(summary.transactionCount, 0);
    expect(summary.totalAmountKurus, 0);
    expect(summary.monthAmountKurus, 0);
    expect(summary.monthTransactionCount, 0);
    expect(summary.recentTransactions, isEmpty);
    expect(summary.month, DateTime(2026, 9));
  });

  test('aktif cari sayısı pasifleri saymaz', () async {
    await addCustomer('Ali');
    await addCustomer('Veli');
    await addCustomer('Pasif', active: false);

    expect((await repo.getSummary()).activeCustomerCount, 2);
  });

  test('toplam sayı ve tutar tüm hareketleri kapsar (pasif cari dahil)',
      () async {
    final ali = await addCustomer('Ali');
    final pasif = await addCustomer('Pasif', active: false);
    await addTx(ali, _kira, '2026-01-10', 125050);
    await addTx(ali, _fatura, '2026-09-10', 100);
    await addTx(pasif, _borc, '2025-12-31', 10);

    final summary = await repo.getSummary();
    expect(summary.transactionCount, 3);
    expect(summary.totalAmountKurus, 125160);
  });

  test('bu ay toplamı ay sınırlarını (1. ve son gün) dahil eder', () async {
    final ali = await addCustomer('Ali');
    await addTx(ali, _kira, '2026-08-31', 1000); // önceki ay
    await addTx(ali, _kira, '2026-09-01', 2000); // ay başı
    await addTx(ali, _kira, '2026-09-15', 3000);
    await addTx(ali, _kira, '2026-09-30', 4000); // ay sonu
    await addTx(ali, _kira, '2026-10-01', 5000); // sonraki ay

    final summary = await repo.getSummary();
    expect(summary.monthAmountKurus, 9000);
    expect(summary.monthTransactionCount, 3);
    expect(summary.transactionCount, 5);
    expect(summary.totalAmountKurus, 15000);
  });

  test('yıl değişiminde ve şubatta ay aralığı doğrudur', () async {
    final ali = await addCustomer('Ali');
    await addTx(ali, _kira, '2024-02-29', 100);
    await addTx(ali, _kira, '2024-03-01', 200);
    final feb = SqliteDashboardRepository(
      appDb.db,
      now: () => DateTime(2024, 2, 10),
    );
    expect((await feb.getSummary()).monthAmountKurus, 100);

    await addTx(ali, _kira, '2026-12-31', 300);
    await addTx(ali, _kira, '2027-01-01', 400);
    final dec = SqliteDashboardRepository(
      appDb.db,
      now: () => DateTime(2026, 12, 5),
    );
    expect((await dec.getSummary()).monthAmountKurus, 300);
  });

  test('son hareketler en yeni 5 kayıttır, adlarla birlikte gelir', () async {
    final ali = await addCustomer('Ahmet', last: 'Yılmaz');
    final veli = await addCustomer('Veli Ltd.');
    await addTx(ali, _kira, '2026-09-01', 1);
    await addTx(ali, _kira, '2026-09-02', 2);
    await addTx(veli, _fatura, '2026-09-03', 3);
    await addTx(ali, _kira, '2026-09-04', 4);
    await addTx(ali, _kira, '2026-09-04', 5); // aynı tarih, daha yüksek id
    await addTx(veli, _borc, '2026-09-06', 6);
    await addTx(ali, _kira, '2026-08-01', 7);

    final recent = (await repo.getSummary()).recentTransactions;

    expect(recent, hasLength(5));
    expect(recent.map((r) => r.amountKurus), [6, 5, 4, 3, 2]);
    expect(recent.first.customerName, 'Veli Ltd.');
    expect(recent.first.transactionTypeName, 'Borç');
    expect(recent.first.transactionDate, DateTime(2026, 9, 6));
    expect(recent[1].customerName, 'Ahmet Yılmaz');
  });

  test('sonuçlar kuruş (integer) üzerinden hesaplanır', () async {
    final ali = await addCustomer('Ali');
    await addTx(ali, _kira, '2026-09-01', 10);
    await addTx(ali, _kira, '2026-09-02', 20);

    final summary = await repo.getSummary();
    expect(summary.totalAmountKurus, 30);
    expect(summary.monthAmountKurus, 30);
  });
}
