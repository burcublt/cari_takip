import 'dart:io';

import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Geçici dizinde dosya tabanlı veritabanı + yedek dizini kurar.
class BackupTestEnv {
  BackupTestEnv._(this.dir, this.database, this.backupDirectory);

  final Directory dir;
  final AppDatabase database;
  final Directory backupDirectory;

  DateTime clock = DateTime(2026, 9, 29, 18, 25);

  String get dbPath => database.path;

  static Future<BackupTestEnv> create() async {
    final dir = await Directory.systemTemp.createTemp('cari_takip_backup_');
    final database = await AppDatabase.open(path: p.join(dir.path, 'cari.db'));
    return BackupTestEnv._(
      dir,
      database,
      Directory(p.join(dir.path, 'backups')),
    );
  }

  late final BackupService service = BackupService(
    database: database,
    backupDirectory: backupDirectory,
    now: () => clock,
  );

  Future<int> addCustomer(String name) {
    return database.db.insert('customers', {
      'first_name': name,
      'is_active': 1,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  Future<int> addTransaction(int customerId, int kurus, {int typeId = 2}) {
    return database.db.insert('financial_transactions', {
      'customer_id': customerId,
      'transaction_type_id': typeId,
      'transaction_date': '2026-09-15',
      'amount_kurus': kurus,
      'note': 'not $kurus',
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
  }

  /// Tüm tabloların içeriğini karşılaştırılabilir metne çevirir.
  Future<String> dump([AppDatabase? target]) async {
    final db = (target ?? database).db;
    final buffer = StringBuffer();
    for (final table in [
      'customers',
      'transaction_types',
      'financial_transactions',
    ]) {
      buffer.writeln(table);
      for (final row in await db.query(table, orderBy: 'id')) {
        buffer.writeln(row);
      }
    }
    return buffer.toString();
  }

  Future<void> dispose() async {
    if (database.db.isOpen) await database.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Dosyayı ham bağlantıyla açıp değiştirir (foreign key kapalı).
Future<void> mutateDatabase(
  String path,
  Future<void> Function(Database db) change,
) async {
  final db = await databaseFactoryFfi.openDatabase(path);
  try {
    await change(db);
  } finally {
    await db.close();
  }
}
