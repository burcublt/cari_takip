import 'package:cari_takip/core/backup/backup_file_chooser.dart';
import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/restore_service.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

BackupInfo makeBackup({
  String name = 'cari_takip_2026-09-29_182500.db',
  BackupKind kind = BackupKind.auto,
  DateTime? createdAt,
  int sizeBytes = 20480,
}) {
  return BackupInfo(
    path: '/yedekler/$name',
    name: name,
    kind: kind,
    createdAt: createdAt ?? DateTime(2026, 9, 29, 18, 25),
    sizeBytes: sizeBytes,
  );
}

class FakeBackupService extends Fake implements BackupService {
  FakeBackupService([List<BackupInfo>? initial]) : backups = [...?initial];

  final List<BackupInfo> backups;
  final List<({BackupKind kind, String? targetPath})> created = [];
  Object? createError;

  @override
  Future<List<BackupInfo>> listBackups() async => [...backups];

  @override
  Future<BackupInfo> createBackup(
    BackupKind kind, {
    String? targetPath,
  }) async {
    final error = createError;
    if (error != null) throw error;
    created.add((kind: kind, targetPath: targetPath));
    final info = makeBackup(
      name: 'cari_takip_manual_2026-09-30_090000.db',
      kind: kind,
      createdAt: DateTime(2026, 9, 30, 9),
    );
    backups.insert(0, info);
    return info;
  }
}

class FakeRestoreService extends Fake implements RestoreService {
  BackupFileInfo info = const BackupFileInfo(
    schemaVersion: 1,
    customerCount: 12,
    transactionCount: 340,
  );
  Object? validateError;
  Object? restoreError;
  final List<String> validated = [];
  final List<String> restored = [];

  @override
  Future<BackupFileInfo> validate(String path) async {
    validated.add(path);
    final error = validateError;
    if (error != null) throw error;
    return info;
  }

  @override
  Future<void> restore(String backupPath) async {
    final error = restoreError;
    if (error != null) throw error;
    restored.add(backupPath);
  }
}

class FakeBackupFileChooser implements BackupFileChooser {
  String? saveLocation;
  String? backupFile;
  final List<String> suggestedNames = [];

  @override
  Future<String?> chooseSaveLocation({required String suggestedName}) async {
    suggestedNames.add(suggestedName);
    return saveLocation;
  }

  @override
  Future<String?> chooseBackupFile() async => backupFile;
}

AppException makeInvalidBackupError() => const AppException(
      AppErrorKind.validation,
      'Seçilen dosya geçerli bir SQLite veritabanı değil.',
    );
