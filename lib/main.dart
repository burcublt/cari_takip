import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/app/restart_scope.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/pre_migration_backup.dart';
import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/database/app_paths.dart';
import 'package:cari_takip/core/database/database_provider.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  try {
    final databasePath = await AppPaths.databasePath();
    // Şema değişecekse (uygulama güncellemesi), veriye dokunmadan önce yedek al.
    await PreMigrationBackup.runIfNeeded(
      databasePath: databasePath,
      backupDirectory: AppPaths.backupDirectory(),
    );
    final database = await AppDatabase.open(path: databasePath);
    await _runDailyBackup(database);
    runApp(
      AppRestartScope(
        builder: (key) => ProviderScope(
          key: key,
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const CariTakipApp(),
        ),
      ),
    );
  } on Object catch (error, stack) {
    debugPrint('Veritabanı açılamadı: $error\n$stack');
    runApp(
      _StartupErrorApp(message: error is AppException ? error.message : null),
    );
  }
}

/// Günde en fazla bir otomatik yedek. Başarısız olursa uygulama yine açılır;
/// Ayarlar ekranındaki "Son yedek" bilgisi eksikliği gösterir.
Future<void> _runDailyBackup(AppDatabase database) async {
  try {
    await BackupService(
      database: database,
      backupDirectory: AppPaths.backupDirectory(),
    ).runDailyBackupIfNeeded();
  } on Object catch (error, stack) {
    debugPrint('Otomatik yedek alınamadı: $error\n$stack');
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({this.message});

  /// Biliniyorsa kullanıcıya gösterilecek özel açıklama.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${message ?? 'Veritabanı açılamadı. Uygulamayı kapatıp yeniden deneyin.'}\n'
              'Sorun devam ederse son yedeğinizden geri yükleyin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
