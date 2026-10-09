import 'dart:io';

import 'package:cari_takip/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _now = '2026-09-29T00:00:00.000Z';

Future<int> _insertCustomer(Database db, {String name = 'Test Cari'}) {
  return db.insert('customers', {
    'first_name': name,
    'is_active': 1,
    'created_at': _now,
    'updated_at': _now,
  });
}

Future<int> _insertTransaction(
  Database db, {
  required int customerId,
  required int typeId,
  int amountKurus = 125050,
}) {
  return db.insert('financial_transactions', {
    'customer_id': customerId,
    'transaction_type_id': typeId,
    'transaction_date': '2026-09-29',
    'amount_kurus': amountKurus,
    'created_at': _now,
    'updated_at': _now,
  });
}

Future<List<Object?>> _names(Database db, String type) async {
  final rows = await db.rawQuery(
    'SELECT name FROM sqlite_master WHERE type = ?',
    [type],
  );
  return rows.map((r) => r['name']).toList();
}

void main() {
  late AppDatabase appDb;
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    db = appDb.db;
  });

  tearDown(() => appDb.close());

  test('şema v1 ve üç tablo oluşur', () async {
    expect(await appDb.schemaVersion(), 1);
    expect(
      await _names(db, 'table'),
      containsAll([
        'customers',
        'transaction_types',
        'financial_transactions',
      ]),
    );
  });

  test('indexler oluşur', () async {
    expect(
      await _names(db, 'index'),
      containsAll([
        'idx_transaction_types_name',
        'idx_transactions_customer',
        'idx_transactions_date',
        'idx_transactions_type',
        'idx_transactions_customer_date',
      ]),
    );
  });

  test('seed işlem tipleri oluşur ve aktiftir', () async {
    final rows = await db.query('transaction_types', orderBy: 'id');
    expect(rows.map((r) => r['name']), [
      'Borç',
      'Kira',
      'Fatura',
      'Vergi',
      'Muhasebe Ücreti',
      'Sigorta',
    ]);
    expect(rows.every((r) => r['is_active'] == 1), isTrue);
  });

  test('foreign key desteği açıktır', () async {
    expect(await appDb.foreignKeysEnabled(), isTrue);
  });

  test('olmayan cari veya tip ile hareket eklenemez', () async {
    final customerId = await _insertCustomer(db);
    await expectLater(
      _insertTransaction(db, customerId: 999, typeId: 1),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      _insertTransaction(db, customerId: customerId, typeId: 999),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('hareketi olan cari ve tip silinemez (RESTRICT)', () async {
    final customerId = await _insertCustomer(db);
    await _insertTransaction(db, customerId: customerId, typeId: 1);

    await expectLater(
      db.delete('customers', where: 'id = ?', whereArgs: [customerId]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('transaction_types', where: 'id = ?', whereArgs: [1]),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('işlem tipi adı büyük/küçük harf duyarsız unique', () async {
    await expectLater(
      db.insert('transaction_types', {
        'name': 'kira',
        'is_active': 1,
        'created_at': _now,
        'updated_at': _now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('tutar kuruş cinsinden INTEGER saklanır', () async {
    final customerId = await _insertCustomer(db);
    await _insertTransaction(
      db,
      customerId: customerId,
      typeId: 1,
      amountKurus: 125050,
    );
    final row = (await db.rawQuery(
      'SELECT amount_kurus, typeof(amount_kurus) AS t '
      'FROM financial_transactions',
    ))
        .single;
    expect(row['amount_kurus'], 125050);
    expect(row['t'], 'integer');
  });

  test('integrity_check başarılıdır', () async {
    expect(await appDb.integrityCheck(), isTrue);
  });

  test('dosya veritabanı yeniden açılınca veri korunur, seed tekrarlanmaz',
      () async {
    final dir = await Directory.systemTemp.createTemp('cari_takip_test_');
    final path = p.join(dir.path, 'cari_takip.db');

    final first = await AppDatabase.open(path: path);
    await _insertCustomer(first.db);
    await first.close();

    final second = await AppDatabase.open(path: path);
    expect(await second.db.query('customers'), hasLength(1));
    expect(await second.db.query('transaction_types'), hasLength(6));
    await second.close();

    await dir.delete(recursive: true);
  });
}
