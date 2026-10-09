import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_validator.dart';
import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/database/database_migrations.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:path/path.dart' as p;

/// Güvenli veritabanı yedekleri: canlı dosya kopyalanmaz; SQLite'ın
/// `VACUUM INTO` anlık görüntüsü önce geçici dosyaya yazılır, doğrulanır ve
/// ancak geçerliyse son adına taşınır.
class BackupService {
  BackupService({
    required this.database,
    required this.backupDirectory,
    DateTime Function()? now,
    this.retentionCount = 30,
  }) : _now = now ?? DateTime.now;

  final AppDatabase database;
  final Directory backupDirectory;
  final int retentionCount;
  final DateTime Function() _now;

  static final _namePattern = RegExp(
    r'^cari_takip_(?:(manual|pre-restore|pre-migration)_)?(\d{4})-(\d{2})-(\d{2})'
    r'_(\d{2})(\d{2})(\d{2})(?:_\d+)?\.db$',
  );

  /// `cari_takip_2026-09-29_182500.db` (manuel: `cari_takip_manual_...`).
  static String suggestedFileName(BackupKind kind, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final stamp = '${AppDate.toDbDate(t)}_${_two(t.hour)}${_two(t.minute)}'
        '${_two(t.second)}';
    return switch (kind) {
      BackupKind.auto => 'cari_takip_$stamp.db',
      BackupKind.manual => 'cari_takip_manual_$stamp.db',
      BackupKind.preRestore => 'cari_takip_pre-restore_$stamp.db',
      BackupKind.preMigration => 'cari_takip_pre-migration_$stamp.db',
    };
  }

  /// Yedek alır. [targetPath] verilmezse yedek dizinine yazılır; verilirse
  /// (kullanıcının seçtiği konum) o dosya, varsa, değiştirilir.
  Future<BackupInfo> createBackup(
    BackupKind kind, {
    String? targetPath,
  }) async {
    final target = await _resolveTargetPath(kind, targetPath);
    if (p.equals(target, database.path)) {
      throw const AppException(
        AppErrorKind.validation,
        'Yedek, veritabanı dosyasının üzerine yazılamaz.',
      );
    }

    final temp = File('$target.part');
    final targetDir = Directory(p.dirname(target));
    try {
      final targetDirType = await FileSystemEntity.type(targetDir.path);
      if (targetDirType == FileSystemEntityType.file) {
        throw const AppException(
          AppErrorKind.storage,
          'Yedek için seçilen hedef bir klasör değil. Klasör izinlerini kontrol edin.',
        );
      }
      if (targetDirType == FileSystemEntityType.notFound) {
        await targetDir.create(recursive: true);
      }

      if (!await _isWritableDirectory(targetDir)) {
        throw const AppException(
          AppErrorKind.storage,
          'Yedek klasörü yazılamıyor. Klasör izinlerini kontrol edin.',
        );
      }

      if (await temp.exists()) await temp.delete();

      await database.vacuumInto(temp.path);
      await BackupValidator.validate(
        temp.path,
        latestSchemaVersion: DatabaseMigrations.latestVersion,
      );
      await temp.rename(target);
    } on Object catch (error, stack) {
      if (await temp.exists()) await temp.delete();
      if (error is AppException) rethrow;
      throw _wrapBackupError(error, stack);
    }

    return BackupInfo(
      path: target,
      name: p.basename(target),
      kind: kind,
      createdAt: _now(),
      sizeBytes: await File(target).length(),
    );
  }

  /// Bugün otomatik yedek yoksa bir tane alır ve eskileri temizler.
  /// Zaten varsa `null` döner.
  Future<BackupInfo?> runDailyBackupIfNeeded() async {
    final today = AppDate.today(_now());
    final hasToday = (await listBackups()).any(
      (b) =>
          b.kind == BackupKind.auto && AppDate.dateOnly(b.createdAt) == today,
    );
    if (hasToday) return null;

    final info = await createBackup(BackupKind.auto);
    await applyRetention();
    return info;
  }

  /// Yedek dizinindeki yedekler, en yeniden eskiye.
  /// Adı yedek desenine uymayan dosyalar yok sayılır.
  Future<List<BackupInfo>> listBackups() async {
    if (!await backupDirectory.exists()) return const [];

    final result = <BackupInfo>[];
    await for (final entity in backupDirectory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final match = _namePattern.firstMatch(name);
      if (match == null) continue;

      result.add(
        BackupInfo(
          path: entity.path,
          name: name,
          kind: switch (match.group(1)) {
            'manual' => BackupKind.manual,
            'pre-restore' => BackupKind.preRestore,
            'pre-migration' => BackupKind.preMigration,
            _ => BackupKind.auto,
          },
          createdAt: DateTime(
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
            int.parse(match.group(4)!),
            int.parse(match.group(5)!),
            int.parse(match.group(6)!),
            int.parse(match.group(7)!),
          ),
          sizeBytes: await entity.length(),
        ),
      );
    }
    result.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.name.compareTo(a.name);
    });
    return result;
  }

  /// En yeni [retentionCount] otomatik yedek dışındakileri siler.
  /// Manuel ve geri yükleme öncesi yedeklere asla dokunmaz.
  /// Silinen dosya sayısını döner.
  Future<int> applyRetention() async {
    final autos =
        (await listBackups()).where((b) => b.kind == BackupKind.auto).toList();
    if (autos.length <= retentionCount) return 0;

    final stale = autos.skip(retentionCount).toList();
    for (final backup in stale) {
      await File(backup.path).delete();
    }
    return stale.length;
  }

  Future<String> _resolveTargetPath(BackupKind kind, String? targetPath) async {
    if (targetPath == null) return _uniquePath(kind);

    final targetType = await FileSystemEntity.type(targetPath);
    if (targetType == FileSystemEntityType.directory) {
      return p.join(targetPath, suggestedFileName(kind, _now()));
    }

    return targetPath;
  }

  Future<String> _uniquePath(BackupKind kind) async {
    final name = suggestedFileName(kind, _now());
    final base = p.join(backupDirectory.path, name);
    if (!await File(base).exists()) return base;

    final stem = p.basenameWithoutExtension(name);
    for (var i = 2;; i++) {
      final candidate = p.join(backupDirectory.path, '${stem}_$i.db');
      if (!await File(candidate).exists()) return candidate;
    }
  }

  static Future<bool> _isWritableDirectory(Directory directory) async {
    try {
      final testFile = File(p.join(directory.path, '.cari_takip_write_test'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } on Object {
      return false;
    }
  }

  static AppException _wrapBackupError(Object error, StackTrace stack) {
    if (error is FileSystemException) {
      final message = error.message.toLowerCase();
      final code = error.osError?.errorCode;
      final noSpace = code == 28 ||
          message.contains('no space') ||
          message.contains('disk full') ||
          message.contains('not enough space');
      if (noSpace) {
        return AppException(
          AppErrorKind.storage,
          'Yedek için yeterli disk alanı yok. Disk alanını boşaltıp tekrar deneyin.',
          cause: error,
          stackTrace: stack,
        );
      }
      if (message.contains('permission denied') ||
          message.contains('access denied') ||
          message.contains('operation not permitted') ||
          message.contains('not permitted')) {
        return AppException(
          AppErrorKind.storage,
          'Yedek klasörü yazılamıyor. Klasör izinlerini kontrol edin.',
          cause: error,
          stackTrace: stack,
        );
      }
    }

    return AppException(
      AppErrorKind.storage,
      'Yedek oluşturulamadı. Disk alanını ve klasör izinlerini kontrol edin.',
      cause: error,
      stackTrace: stack,
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
