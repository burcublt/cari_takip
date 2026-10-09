import 'package:cari_takip/core/database/database_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('en son sürüm 1', () {
    expect(DatabaseMigrations.latestVersion, 1);
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
