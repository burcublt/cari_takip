import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/transaction_types/data/sqlite_transaction_type_repository.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Matcher _appError(AppErrorKind kind) =>
    isA<AppException>().having((e) => e.kind, 'kind', kind);

void main() {
  late AppDatabase appDb;
  late SqliteTransactionTypeRepository repo;
  var clock = DateTime.utc(2026, 9, 29, 10);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    clock = DateTime.utc(2026, 9, 29, 10);
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = SqliteTransactionTypeRepository(appDb.db, now: () => clock);
  });

  tearDown(() => appDb.close());

  Future<int> idOf(String name) async {
    final all = await repo.getTransactionTypes(
      status: TransactionTypeStatusFilter.all,
    );
    return all.firstWhere((t) => t.name == name).id;
  }

  test('seed tipleri alfabetik ve aktif olarak gelir', () async {
    final types = await repo.getTransactionTypes();
    expect(types.map((t) => t.name), [
      'Borç',
      'Fatura',
      'Kira',
      'Muhasebe Ücreti',
      'Sigorta',
      'Vergi',
    ]);
    expect(types.every((t) => t.isActive), isTrue);
  });

  group('createTransactionType', () {
    test('trim eder, iç boşlukları sadeleştirir, aktif başlatır', () async {
      final created = await repo.createTransactionType('  Aidat   Ödemesi ');

      expect(created.name, 'Aidat Ödemesi');
      expect(created.isActive, isTrue);
      expect(created.createdAt, clock);
      expect(created.updatedAt, clock);
      expect(await repo.getTransactionTypes(), hasLength(7));
    });

    test('boş ad reddedilir', () async {
      await expectLater(
        repo.createTransactionType('   '),
        throwsA(_appError(AppErrorKind.validation)),
      );
    });

    test('aynı isim (büyük/küçük harf, Türkçe, aksan) duplicate olur',
        () async {
      for (final name in ['Kira', 'kira', 'KİRA', 'BORÇ', 'borc', '  Kira ']) {
        await expectLater(
          repo.createTransactionType(name),
          throwsA(
            isA<AppException>()
                .having((e) => e.kind, 'kind', AppErrorKind.duplicate)
                .having(
                  (e) => e.message,
                  'message',
                  duplicateTransactionTypeMessage,
                ),
          ),
          reason: name,
        );
      }
      expect(await repo.getTransactionTypes(), hasLength(6));
    });

    test('pasif tiple aynı isim de duplicate olur', () async {
      await repo.setTransactionTypeActive(await idOf('Kira'), isActive: false);
      await expectLater(
        repo.createTransactionType('kira'),
        throwsA(_appError(AppErrorKind.duplicate)),
      );
    });
  });

  group('renameTransactionType', () {
    test('adı değiştirir; durum ve createdAt korunur', () async {
      final id = await idOf('Kira');
      await repo.setTransactionTypeActive(id, isActive: false);
      // Seed kayıtlar migration anındaki gerçek saatle oluşur (sabit saatle değil).
      final createdBefore = (await repo.getTransactionTypeById(id))!.createdAt;

      clock = DateTime.utc(2026, 10, 1, 9);
      final renamed = await repo.renameTransactionType(id, ' Ofis  Kirası ');

      expect(renamed.name, 'Ofis Kirası');
      expect(renamed.isActive, isFalse);
      expect(renamed.createdAt, createdBefore);
      expect(renamed.updatedAt, DateTime.utc(2026, 10, 1, 9));
    });

    test('kendi adının harf büyüklüğünü değiştirmek serbesttir', () async {
      final id = await idOf('Kira');
      final renamed = await repo.renameTransactionType(id, 'KİRA');
      expect(renamed.name, 'KİRA');
    });

    test('başka bir tipin adına yeniden adlandırma reddedilir', () async {
      final id = await idOf('Kira');
      await expectLater(
        repo.renameTransactionType(id, 'vergi'),
        throwsA(_appError(AppErrorKind.duplicate)),
      );
      expect((await repo.getTransactionTypeById(id))!.name, 'Kira');
    });

    test('boş ad reddedilir, olmayan tip notFound verir', () async {
      final id = await idOf('Kira');
      await expectLater(
        repo.renameTransactionType(id, ' '),
        throwsA(_appError(AppErrorKind.validation)),
      );
      await expectLater(
        repo.renameTransactionType(999, 'Yeni'),
        throwsA(_appError(AppErrorKind.notFound)),
      );
    });
  });

  group('setTransactionTypeActive', () {
    test('pasife alır, varsayılan listeden çıkarır, tekrar aktif eder',
        () async {
      final id = await idOf('Kira');

      await repo.setTransactionTypeActive(id, isActive: false);
      expect(
        (await repo.getTransactionTypes()).map((t) => t.name),
        isNot(contains('Kira')),
      );
      expect(
        (await repo.getTransactionTypes(
          status: TransactionTypeStatusFilter.inactive,
        ))
            .single
            .name,
        'Kira',
      );

      await repo.setTransactionTypeActive(id, isActive: true);
      expect(
        (await repo.getTransactionTypes()).map((t) => t.name),
        contains('Kira'),
      );
    });

    test('olmayan tip notFound verir', () async {
      await expectLater(
        repo.setTransactionTypeActive(999, isActive: false),
        throwsA(_appError(AppErrorKind.notFound)),
      );
    });

    test('hareketlerde kullanılan tip pasife alınınca kaydı korunur', () async {
      final typeId = await idOf('Kira');
      final customerId = await appDb.db.insert('customers', {
        'first_name': 'Ali',
        'is_active': 1,
        'created_at': '2026-09-29T00:00:00.000Z',
        'updated_at': '2026-09-29T00:00:00.000Z',
      });
      await appDb.db.insert('financial_transactions', {
        'customer_id': customerId,
        'transaction_type_id': typeId,
        'transaction_date': '2026-09-29',
        'amount_kurus': 100,
        'created_at': '2026-09-29T00:00:00.000Z',
        'updated_at': '2026-09-29T00:00:00.000Z',
      });

      await repo.setTransactionTypeActive(typeId, isActive: false);

      final type = await repo.getTransactionTypeById(typeId);
      expect(type, isNotNull);
      expect(type!.isActive, isFalse);
      expect(
        await appDb.db.query(
          'financial_transactions',
          where: 'transaction_type_id = ?',
          whereArgs: [typeId],
        ),
        hasLength(1),
      );
    });
  });

  test('getTransactionTypeById olmayan kayıt için null döner', () async {
    expect(await repo.getTransactionTypeById(999), isNull);
  });
}
