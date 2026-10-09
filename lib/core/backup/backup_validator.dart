import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Bir dosyanın geçerli bir Cari Takip veritabanı/yedeği olup olmadığını
/// salt-okunur açarak doğrular. Dosyayı asla değiştirmez.
abstract final class BackupValidator {
  static const _sqliteHeader = 'SQLite format 3\u0000';

  static const _requiredColumns = <String, Set<String>>{
    'customers': {
      'id',
      'first_name',
      'last_name',
      'phone',
      'tax_number',
      'tax_office',
      'address',
      'note',
      'is_active',
      'created_at',
      'updated_at',
    },
    'transaction_types': {
      'id',
      'name',
      'is_active',
      'created_at',
      'updated_at',
    },
    'financial_transactions': {
      'id',
      'customer_id',
      'transaction_type_id',
      'transaction_date',
      'amount_kurus',
      'note',
      'created_at',
      'updated_at',
    },
  };

  /// Geçerliyse özetini döner; değilse kullanıcıya gösterilebilir mesajlı
  /// bir [AppException] (`validation`) fırlatır.
  static Future<BackupFileInfo> validate(
    String path, {
    required int latestSchemaVersion,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw _invalid('Seçilen dosya bulunamadı.');
    }
    await _checkHeader(file);

    Database? db;
    try {
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );

      final versionRows = await db.rawQuery('PRAGMA user_version');
      final version = versionRows.first.values.first! as int;
      if (version > latestSchemaVersion) {
        throw _invalid(
          'Bu yedek, uygulamanın daha yeni bir sürümüyle alınmış. '
          'Lütfen uygulamayı güncelleyin.',
        );
      }
      if (version < 1) throw _notABackup();

      for (final entry in _requiredColumns.entries) {
        final info = await db.rawQuery('PRAGMA table_info(${entry.key})');
        final columns = info.map((r) => r['name']! as String).toSet();
        if (!columns.containsAll(entry.value)) throw _notABackup();
      }

      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.length != 1 || integrity.first.values.first != 'ok') {
        throw _invalid('Yedek dosyası bozuk görünüyor.');
      }

      final fkViolations = await db.rawQuery('PRAGMA foreign_key_check');
      if (fkViolations.isNotEmpty) {
        throw _invalid(
          'Yedek dosyasındaki kayıtlar tutarsız (ilişkili kayıt hataları).',
        );
      }

      final customers = await db.rawQuery('SELECT COUNT(*) AS c FROM customers');
      final transactions = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM financial_transactions',
      );
      return BackupFileInfo(
        schemaVersion: version,
        customerCount: customers.first['c']! as int,
        transactionCount: transactions.first['c']! as int,
      );
    } on AppException {
      rethrow;
    } on Object {
      throw _invalid('Seçilen dosya okunamadı veya bozuk.');
    } finally {
      await db?.close();
    }
  }

  static Future<void> _checkHeader(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(16);
      if (String.fromCharCodes(bytes) != _sqliteHeader) {
        throw _invalid('Seçilen dosya geçerli bir SQLite veritabanı değil.');
      }
    } finally {
      await handle.close();
    }
  }

  static AppException _notABackup() => _invalid(
        'Seçilen dosya bir Cari Takip yedeği değil (gerekli tablolar eksik).',
      );

  static AppException _invalid(String message) =>
      AppException(AppErrorKind.validation, message);
}
