import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/backup_validator.dart';
import 'package:cari_takip/core/database/database_migrations.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uygulama güncellenip veritabanı şeması değişecekse (migration), değişiklik
/// başlamadan önce mevcut verinin doğrulanmış bir yedeğini alır.
///
/// Migration çalışmadan ÖNCE, veritabanı normal açılışla açılmadan çağrılmalıdır.
/// Yedek alınamazsa [AppException] fırlatılır; veritabanına dokunulmaz ve
/// uygulama güncellenmiş şemayla açılmaz.
abstract final class PreMigrationBackup {
  /// Şema güncellenecekse yedeği ve bilgisini döner; gerek yoksa (yeni kurulum,
  /// boş dosya veya şema zaten güncel) `null` döner.
  ///
  /// [latestVersion] yalnızca testlerde, ileri bir şema sürümünü taklit etmek
  /// için verilir.
  static Future<BackupInfo?> runIfNeeded({
    required String databasePath,
    required Directory backupDirectory,
    int? latestVersion,
    DateTime Function()? now,
  }) async {
    final latest = latestVersion ?? DatabaseMigrations.latestVersion;
    if (databasePath == inMemoryDatabasePath ||
        !await File(databasePath).exists()) {
      return null;
    }

    Database? probe;
    File? temp;
    try {
      // `version` verilmediği için migration çalışmaz; yalnızca sürüm okunur.
      probe = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final current = await probe.getVersion();
      if (current < 1 || current >= latest) return null;

      final time = now?.call() ?? DateTime.now();
      final target = await _uniquePath(backupDirectory, time);
      temp = File('$target.part');

      await backupDirectory.create(recursive: true);
      if (await temp.exists()) await temp.delete();

      final escaped = temp.path.replaceAll("'", "''");
      await probe.execute("VACUUM INTO '$escaped'");
      await BackupValidator.validate(temp.path, latestSchemaVersion: latest);
      await temp.rename(target);

      return BackupInfo(
        path: target,
        name: p.basename(target),
        kind: BackupKind.preMigration,
        createdAt: time,
        sizeBytes: await File(target).length(),
      );
    } on Object catch (error, stack) {
      if (error is AppException) rethrow;
      throw AppException(
        AppErrorKind.storage,
        'Güncelleme öncesi yedek alınamadı; verileriniz değiştirilmedi. '
        'Disk alanını ve klasör izinlerini kontrol edin.',
        cause: error,
        stackTrace: stack,
      );
    } finally {
      await probe?.close();
      if (temp != null && await temp.exists()) await temp.delete();
    }
  }

  static Future<String> _uniquePath(Directory dir, DateTime time) async {
    final name = BackupService.suggestedFileName(BackupKind.preMigration, time);
    final base = p.join(dir.path, name);
    if (!await File(base).exists()) return base;

    final stem = p.basenameWithoutExtension(name);
    for (var i = 2;; i++) {
      final candidate = p.join(dir.path, '${stem}_$i.db');
      if (!await File(candidate).exists()) return candidate;
    }
  }
}
