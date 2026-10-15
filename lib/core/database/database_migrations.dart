import 'package:cari_takip/core/database/database_indexes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef MigrationStep = Future<void> Function(DatabaseExecutor db);

class Migration {
  const Migration(this.version, this.run);

  final int version;
  final MigrationStep run;
}

/// Şema değişiklikleri yalnızca buraya yeni bir [Migration] eklenerek yapılır.
/// Mevcut migration'lar değiştirilmez; kullanıcının veritabanı asla silinmez.
///
/// TODO(faz-9): Upgrade öncesi otomatik yedek alınacak.
abstract final class DatabaseMigrations {
  static const all = <Migration>[
    Migration(1, _v1),
    Migration(2, _v2),
    Migration(3, _v3),
  ];

  static int get latestVersion => all.last.version;

  /// [from] (hariç) ile [to] (dahil) arasındaki migration'ları sırayla çalıştırır.
  static Future<void> migrate(
    DatabaseExecutor db, {
    required int from,
    required int to,
    List<Migration> migrations = all,
  }) async {
    final pending = migrations
        .where((m) => m.version > from && m.version <= to)
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    for (final migration in pending) {
      await migration.run(db);
    }
  }

  static const _seedTransactionTypes = <String>[
    'Borç',
    'Kira',
    'Fatura',
    'Vergi',
    'Muhasebe Ücreti',
    'Sigorta',
  ];

  static Future<void> _v1(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name TEXT NOT NULL,
    last_name TEXT,
    phone TEXT,
    tax_number TEXT,
    tax_office TEXT,
    address TEXT,
    note TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
)''');

    await db.execute('''
CREATE TABLE transaction_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL COLLATE NOCASE,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
)''');

    await db.execute('''
CREATE TABLE financial_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    transaction_type_id INTEGER NOT NULL,
    transaction_date TEXT NOT NULL,
    amount_kurus INTEGER NOT NULL,
    note TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (customer_id)
        REFERENCES customers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    FOREIGN KEY (transaction_type_id)
        REFERENCES transaction_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
)''');

    for (final sql in DatabaseIndexes.v1) {
      await db.execute(sql);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    for (final name in _seedTransactionTypes) {
      await db.insert('transaction_types', {
        'name': name,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  static Future<void> _v2(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE customers ADD COLUMN accounting_fee_kurus INTEGER',
    );
  }

  static Future<void> _v3(DatabaseExecutor db) async {
    await db.execute('''
ALTER TABLE financial_transactions
ADD COLUMN direction TEXT NOT NULL DEFAULT 'debt'
CHECK (direction IN ('debt', 'collection'))''');
    await db.update(
      'transaction_types',
      {'is_active': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'name = ?',
      whereArgs: ['Borç'],
    );
  }
}
