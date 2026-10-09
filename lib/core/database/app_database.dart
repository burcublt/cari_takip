import 'package:cari_takip/core/database/app_paths.dart';
import 'package:cari_takip/core/database/database_migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite bağlantısını açar, foreign key'leri etkinleştirir ve migration'ları
/// çalıştırır. UI bu sınıfa doğrudan erişmez; repository'ler kullanır.
///
/// Yedekten geri yükleme sırasında bağlantı kapatılıp yeniden açılabilir
/// ([reopen]); bu yüzden [db] her çağrıda güncel bağlantıyı döndürür.
class AppDatabase {
  AppDatabase._(this.path, this._db);

  /// Veritabanı dosyasının yolu (bellek içi veritabanında `:memory:`).
  final String path;
  Database _db;

  Database get db => _db;

  /// `sqfliteFfiInit()` daha önce çağrılmış olmalıdır.
  static Future<AppDatabase> openDefault() async {
    return open(path: await AppPaths.databasePath());
  }

  static Future<AppDatabase> open({required String path}) async {
    return AppDatabase._(path, await _openDatabase(path));
  }

  static Future<Database> _openDatabase(String path) {
    final inMemory = path == inMemoryDatabasePath;
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.latestVersion,
        singleInstance: !inMemory,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) =>
            DatabaseMigrations.migrate(db, from: 0, to: version),
        onUpgrade: (db, oldVersion, newVersion) =>
            DatabaseMigrations.migrate(db, from: oldVersion, to: newVersion),
        onDowngrade: (db, oldVersion, newVersion) {
          throw StateError(
            'Veritabanı (v$oldVersion) bu uygulama sürümünden (v$newVersion) '
            'daha yeni. Veri korunması için açılmadı.',
          );
        },
      ),
    );
  }

  /// Bağlantıyı (kapalıysa kapatmadan) aynı dosya yolundan yeniden açar.
  /// Önceki [db] referanslarını tutan nesneler geçersiz olur.
  Future<void> reopen() async {
    if (_db.isOpen) await _db.close();
    _db = await _openDatabase(path);
  }

  /// Canlı veritabanının tutarlı bir anlık görüntüsünü [targetPath]'e yazar
  /// (SQLite `VACUUM INTO`). Hedef dosya mevcut olmamalıdır.
  Future<void> vacuumInto(String targetPath) {
    final escaped = targetPath.replaceAll("'", "''");
    return _db.execute("VACUUM INTO '$escaped'");
  }

  Future<int> schemaVersion() => _db.getVersion();

  Future<bool> foreignKeysEnabled() async {
    final rows = await _db.rawQuery('PRAGMA foreign_keys');
    return rows.first.values.first == 1;
  }

  Future<bool> integrityCheck() async {
    final rows = await _db.rawQuery('PRAGMA integrity_check');
    return rows.length == 1 && rows.first.values.first == 'ok';
  }

  Future<void> close() => _db.close();
}
