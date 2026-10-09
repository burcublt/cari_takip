import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/backup_validator.dart';
import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/database/database_migrations.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:path/path.dart' as p;

/// Geri yükleme başarısız olduğunda, veritabanı bağlantısı kapatılıp yeniden
/// açıldığı için uygulamanın yeniden başlatılması gerekiyorsa
/// [requiresRestart] `true` olur.
class RestoreException extends AppException {
  const RestoreException(
    String message, {
    required this.requiresRestart,
    super.cause,
    super.stackTrace,
  }) : super(AppErrorKind.storage, message);

  final bool requiresRestart;
}

/// Yedekten geri yükleme. Mevcut veri, işlem başarısız olursa geri konur.
class RestoreService {
  RestoreService({
    required this.database,
    required this.backupService,
    Future<void> Function(AppDatabase database)? verifyAfterRestore,
  }) : _verify = verifyAfterRestore ?? _defaultVerify;

  final AppDatabase database;
  final BackupService backupService;
  final Future<void> Function(AppDatabase database) _verify;

  static Future<void> _defaultVerify(AppDatabase database) async {
    if (!await database.integrityCheck()) {
      throw StateError('Geri yüklenen veritabanı bütünlük kontrolünden geçmedi.');
    }
    if (!await database.foreignKeysEnabled()) {
      throw StateError('Foreign key desteği etkin değil.');
    }
  }

  /// Dosyanın geçerli bir yedek olduğunu doğrular (veriye dokunmaz).
  Future<BackupFileInfo> validate(String path) {
    return BackupValidator.validate(
      path,
      latestSchemaVersion: DatabaseMigrations.latestVersion,
    );
  }

  /// Sıra: doğrula -> güvenlik yedeği al -> hazırla ve yeniden doğrula ->
  /// bağlantıyı kapat -> dosyayı değiştir -> yeniden aç -> kontrol et.
  /// Bağlantı kapatıldıktan sonra bir şey ters giderse eski dosya geri konur.
  Future<void> restore(String backupPath) async {
    final dbPath = database.path;
    if (p.equals(backupPath, dbPath)) {
      throw const AppException(
        AppErrorKind.validation,
        'Geçerli veritabanı dosyası yedek olarak seçilemez.',
      );
    }

    final staged = File('$dbPath.restore');
    final old = File('$dbPath.old');
    final BackupInfo safety;

    // Bu aşamada herhangi bir hata mevcut veriyi değiştirmez.
    try {
      await validate(backupPath);
      safety = await backupService.createBackup(BackupKind.preRestore);
      await _deleteIfExists(staged);
      await _deleteIfExists(old);
      await File(backupPath).copy(staged.path);
      await validate(staged.path);
    } on Object catch (error, stack) {
      await _deleteIfExists(staged);
      if (error is AppException) rethrow;
      throw AppException(
        AppErrorKind.storage,
        'Geri yükleme başlatılamadı. Mevcut verileriniz değişmedi.',
        cause: error,
        stackTrace: stack,
      );
    }

    try {
      await database.close();
      await _deleteSidecars(dbPath);
      await File(dbPath).rename(old.path);
      await staged.rename(dbPath);
      await database.reopen();
      await _verify(database);
      await _deleteIfExists(old);
    } on Object catch (error, stack) {
      await _rollback(
        dbPath: dbPath,
        old: old,
        staged: staged,
        safety: safety,
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<Never> _rollback({
    required String dbPath,
    required File old,
    required File staged,
    required BackupInfo safety,
    required Object cause,
    required StackTrace stackTrace,
  }) async {
    try {
      if (database.db.isOpen) await database.db.close();
      if (await old.exists()) {
        await _deleteIfExists(File(dbPath));
        await _deleteSidecars(dbPath);
        await old.rename(dbPath);
      }
      await _deleteIfExists(staged);
      await database.reopen();
    } on Object catch (rollbackError) {
      throw RestoreException(
        'Geri yükleme başarısız oldu ve veritabanı yeniden açılamadı. '
        'Verilerinizin güvenlik yedeği: ${safety.path}',
        requiresRestart: true,
        cause: rollbackError,
        stackTrace: stackTrace,
      );
    }
    throw RestoreException(
      'Geri yükleme tamamlanamadı. Mevcut verileriniz korundu.',
      requiresRestart: true,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  Future<void> _deleteSidecars(String dbPath) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      await _deleteIfExists(File('$dbPath$suffix'));
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }
}
