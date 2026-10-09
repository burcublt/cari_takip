import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_validator.dart';
import 'package:cari_takip/core/backup/pre_migration_backup.dart';
import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;
  late String dbPath;
  late Directory backups;
  final fixedNow = DateTime(2026, 10, 4, 9, 30, 15);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cari_takip_premig_');
    dbPath = p.join(dir.path, 'cari.db');
    backups = Directory(p.join(dir.path, 'backups'));

    // v1 şemalı, içinde veri olan gerçek bir veritabanı hazırla.
    final db = await AppDatabase.open(path: dbPath);
    final ali = await db.db.insert('customers', {
      'first_name': 'Ali',
      'is_active': 1,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
    await db.db.insert('financial_transactions', {
      'customer_id': ali,
      'transaction_type_id': 2,
      'transaction_date': '2026-09-15',
      'amount_kurus': 125050,
      'created_at': '2026-09-29T00:00:00.000Z',
      'updated_at': '2026-09-29T00:00:00.000Z',
    });
    await db.close();
  });

  tearDown(() async {
    if (await dir.exists()) {
      // Salt-okunur yapılmış klasörler silinebilsin.
      if (!Platform.isWindows) {
        await Process.run('chmod', ['-R', '755', dir.path]);
      }
      await dir.delete(recursive: true);
    }
  });

  Future<List<String>> names() async => [
        if (await backups.exists())
          await for (final e in backups.list()) p.basename(e.path),
      ];

  test('şema güncellenecekse geçerli bir güvenlik yedeği alır', () async {
    final info = await PreMigrationBackup.runIfNeeded(
      databasePath: dbPath,
      backupDirectory: backups,
      latestVersion: 2,
      now: () => fixedNow,
    );

    expect(info, isNotNull);
    expect(info!.kind, BackupKind.preMigration);
    expect(info.name, 'cari_takip_pre-migration_2026-10-04_093015.db');
    expect(info.createdAt, fixedNow);
    expect(info.sizeBytes, greaterThan(0));
    expect(await names(), [info.name]);

    final content = await BackupValidator.validate(
      info.path,
      latestSchemaVersion: 2,
    );
    expect(content.schemaVersion, 1);
    expect(content.customerCount, 1);
    expect(content.transactionCount, 1);
  });

  test('yedek alırken asıl veritabanı değişmez', () async {
    final before = await File(dbPath).readAsBytes();

    await PreMigrationBackup.runIfNeeded(
      databasePath: dbPath,
      backupDirectory: backups,
      latestVersion: 2,
      now: () => fixedNow,
    );

    expect(await File(dbPath).readAsBytes(), before);
    final db = await AppDatabase.open(path: dbPath);
    expect(await db.db.query('customers'), hasLength(1));
    expect(await db.schemaVersion(), 1);
    await db.close();
  });

  test('şema zaten güncelse yedek almaz ve yedek klasörü oluşturmaz', () async {
    final info = await PreMigrationBackup.runIfNeeded(
      databasePath: dbPath,
      backupDirectory: backups,
    );

    expect(info, isNull);
    expect(await backups.exists(), isFalse);
  });

  test('yeni kurulumda (veritabanı dosyası yok) yedek almaz', () async {
    final info = await PreMigrationBackup.runIfNeeded(
      databasePath: p.join(dir.path, 'yok.db'),
      backupDirectory: backups,
      latestVersion: 2,
    );

    expect(info, isNull);
    expect(await backups.exists(), isFalse);
  });

  test('henüz şema kurulmamış boş dosyada yedek almaz', () async {
    final emptyPath = p.join(dir.path, 'bos.db');
    final raw = await databaseFactoryFfi.openDatabase(emptyPath);
    await raw.close();

    final info = await PreMigrationBackup.runIfNeeded(
      databasePath: emptyPath,
      backupDirectory: backups,
      latestVersion: 2,
    );

    expect(info, isNull);
  });

  test('bellek içi veritabanında yedek almaz', () async {
    final info = await PreMigrationBackup.runIfNeeded(
      databasePath: inMemoryDatabasePath,
      backupDirectory: backups,
      latestVersion: 2,
    );
    expect(info, isNull);
  });

  test('aynı saniyede ikinci kez çalışırsa öncekinin üzerine yazmaz', () async {
    final first = await PreMigrationBackup.runIfNeeded(
      databasePath: dbPath,
      backupDirectory: backups,
      latestVersion: 2,
      now: () => fixedNow,
    );
    final second = await PreMigrationBackup.runIfNeeded(
      databasePath: dbPath,
      backupDirectory: backups,
      latestVersion: 2,
      now: () => fixedNow,
    );

    expect(first!.path, isNot(second!.path));
    expect(second.name, 'cari_takip_pre-migration_2026-10-04_093015_2.db');
    expect(await names(), hasLength(2));
  });

  test('yedek alınamazsa hata verir; veritabanı ve klasör temiz kalır',
      () async {
    await backups.create();
    await Process.run('chmod', ['555', backups.path]); // Windows'ta test atlanır
    final before = await File(dbPath).readAsBytes();

    await expectLater(
      PreMigrationBackup.runIfNeeded(
        databasePath: dbPath,
        backupDirectory: backups,
        latestVersion: 2,
        now: () => fixedNow,
      ),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.storage)
            .having((e) => e.message, 'message', contains('değiştirilmedi')),
      ),
    );

    expect(await File(dbPath).readAsBytes(), before);
    expect(await names(), isEmpty);
  }, skip: Platform.isWindows);

  test('bozuk (SQLite olmayan) dosya AppException ile reddedilir', () async {
    final junk = p.join(dir.path, 'bozuk.db');
    await File(junk).writeAsString('bu bir veritabanı değil, düz metin');

    await expectLater(
      PreMigrationBackup.runIfNeeded(
        databasePath: junk,
        backupDirectory: backups,
        latestVersion: 2,
      ),
      throwsA(isA<AppException>()),
    );
    expect(await backups.exists(), isFalse);
  });
}
