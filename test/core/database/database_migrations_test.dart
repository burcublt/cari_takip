import 'package:cari_takip/core/database/database_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('en son sürüm 3', () {
    expect(DatabaseMigrations.latestVersion, 3);
  });

  test('v3 eski finans hareketlerini borç olarak korur', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.migrate(db, from: 0, to: 2);
    final customerId = await db.insert('customers', {
      'first_name': 'Ali',
      'is_active': 1,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
    await db.insert('financial_transactions', {
      'customer_id': customerId,
      'transaction_type_id': 2,
      'transaction_date': '2026-09-29',
      'amount_kurus': 10000,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });

    await DatabaseMigrations.migrate(db, from: 2, to: 3);

    expect(
      (await db.query('financial_transactions')).single['direction'],
      'debt',
    );
    final debtCategory = await db.query(
      'transaction_types',
      where: 'name = ?',
      whereArgs: ['Borç'],
    );
    expect(debtCategory.single['is_active'], 0);
    await db.close();
  });

  test('v2 mevcut carileri korur ve muhasebe ücreti alanını ekler', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.migrate(db, from: 0, to: 1);
    await db.insert('customers', {
      'first_name': 'Ali',
      'is_active': 1,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });

    await DatabaseMigrations.migrate(db, from: 1, to: 2);

    final customer = (await db.query('customers')).single;
    expect(customer['first_name'], 'Ali');
    expect(customer['accounting_fee_kurus'], isNull);
    await db.close();
  });

  test('migrate yalnızca bekleyen sürümleri çalıştırır ve veriyi korur',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.migrate(db, from: 0, to: 1);
    await db.insert('customers', {
      'first_name': 'Ali',
      'is_active': 1,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });

    final v2 = Migration(
      2,
      (e) => e.execute('ALTER TABLE customers ADD COLUMN email TEXT'),
    );
    await DatabaseMigrations.migrate(
      db,
      from: 1,
      to: 2,
      migrations: [...DatabaseMigrations.all, v2],
    );

    final columns = await db.rawQuery('PRAGMA table_info(customers)');
    expect(columns.map((c) => c['name']), contains('email'));
    expect((await db.query('customers')).single['first_name'], 'Ali');
    await db.close();
  });

  test('from == to ise hiçbir migration çalışmaz', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.migrate(db, from: 1, to: 1);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'customers'",
    );
    expect(tables, isEmpty);
    await db.close();
  });
}
