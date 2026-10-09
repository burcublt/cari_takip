import 'dart:io';

import 'package:cari_takip/core/backup/backup_file_chooser.dart';
import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/restore_service.dart';
import 'package:cari_takip/core/database/app_paths.dart';
import 'package:cari_takip/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    database: ref.watch(appDatabaseProvider),
    backupDirectory: AppPaths.backupDirectory(),
  ),
);

final restoreServiceProvider = Provider<RestoreService>(
  (ref) => RestoreService(
    database: ref.watch(appDatabaseProvider),
    backupService: ref.watch(backupServiceProvider),
  ),
);

final backupFileChooserProvider = Provider<BackupFileChooser>(
  (ref) => const FileSelectorBackupChooser(),
);

/// Veritabanı bütünlük kontrolü (`PRAGMA integrity_check`) çalıştırır.
final integrityCheckerProvider = Provider<Future<bool> Function()>(
  (ref) => ref.read(appDatabaseProvider).integrityCheck,
);

final backupListProvider = FutureProvider.autoDispose<List<BackupInfo>>((ref) {
  return ref.watch(backupServiceProvider).listBackups();
});

class SystemInfo {
  const SystemInfo({
    required this.dataDirectory,
    required this.databasePath,
    required this.backupDirectory,
    required this.schemaVersion,
    required this.databaseSizeBytes,
  });

  final String dataDirectory;
  final String databasePath;
  final String backupDirectory;
  final int schemaVersion;
  final int databaseSizeBytes;
}

final systemInfoProvider = FutureProvider.autoDispose<SystemInfo>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  final file = File(database.path);
  return SystemInfo(
    dataDirectory: p.dirname(database.path),
    databasePath: database.path,
    backupDirectory: AppPaths.backupDirectory().path,
    schemaVersion: await database.schemaVersion(),
    databaseSizeBytes: await file.exists() ? await file.length() : 0,
  );
});
