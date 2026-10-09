import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/backup_validator.dart';
import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/backup_test_env.dart';

void main() {
  late BackupTestEnv env;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    env = await BackupTestEnv.create();
    final ali = await env.addCustomer('Ali');
    await env.addTransaction(ali, 125050);
  });

  tearDown(() => env.dispose());

  Future<List<String>> backupNames() async =>
      (await env.service.listBackups()).map((b) => b.name).toList();

  Future<BackupFileInfo> validate(String path) => BackupValidator.validate(
        path,
        latestSchemaVersion: 1,
      );

  group('createBackup', () {
    test('yedek dizininde zaman damgalı adla geçerli bir dosya oluşturur',
        () async {
      final info = await env.service.createBackup(BackupKind.auto);

      expect(info.name, 'cari_takip_2026-09-29_182500.db');
      expect(info.kind, BackupKind.auto);
      expect(p.dirname(info.path), env.backupDirectory.path);
      expect(info.sizeBytes, greaterThan(0));
      expect(await File(info.path).exists(), isTrue);

      final content = await validate(info.path);
      expect(content.customerCount, 1);
      expect(content.transactionCount, 1);
    });

    test('manuel ve geri yükleme öncesi yedeklerin adları ayrışır', () async {
      final manual = await env.service.createBackup(BackupKind.manual);
      final safety = await env.service.createBackup(BackupKind.preRestore);

      expect(manual.name, 'cari_takip_manual_2026-09-29_182500.db');
      expect(safety.name, 'cari_takip_pre-restore_2026-09-29_182500.db');
    });

    test('yedek, o andaki veriyi içerir; sonraki değişiklikleri içermez',
        () async {
      final first = await env.service.createBackup(BackupKind.manual);
      await env.addCustomer('Veli');
      env.clock = env.clock.add(const Duration(minutes: 5));
      final second = await env.service.createBackup(BackupKind.manual);

      expect((await validate(first.path)).customerCount, 1);
      expect((await validate(second.path)).customerCount, 2);
    });

    test('canlı veritabanı açıkken ve yazılırken tutarlı yedek alınır',
        () async {
      final ali = await env.addCustomer('Ayşe');
      final writes = [
        for (var i = 1; i <= 20; i++) env.addTransaction(ali, i * 100),
      ];
      final info = await env.service.createBackup(BackupKind.manual);
      await Future.wait(writes);

      final result = await validate(info.path);
      expect(result.transactionCount, greaterThanOrEqualTo(1));
    });

    test('şema sürümü yedekte korunur', () async {
      final info = await env.service.createBackup(BackupKind.manual);
      final db = await databaseFactoryFfi.openDatabase(
        info.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        expect(await db.getVersion(), 1);
      } finally {
        await db.close();
      }
    });

    test('kullanıcının seçtiği konuma yazar ve mevcut dosyanın üzerine geçer',
        () async {
      final target = p.join(env.dir.path, 'disari', 'benim_yedegim.db');
      await Directory(p.dirname(target)).create();
      await File(target).writeAsString('eski içerik');

      final info = await env.service.createBackup(
        BackupKind.manual,
        targetPath: target,
      );

      expect(info.path, target);
      expect((await validate(target)).customerCount, 1);
      expect(await File('$target.part').exists(), isFalse);
    });

    test('klasör yolu verildiğinde dosyanın o klasöre yazılmasını sağlar',
        () async {
      final directory = Directory(p.join(env.dir.path, 'hedef_klasor'));
      await directory.create();

      final info = await env.service.createBackup(
        BackupKind.manual,
        targetPath: directory.path,
      );

      expect(p.dirname(info.path), directory.path);
      expect(p.basename(info.path), startsWith('cari_takip_manual_'));
      expect(await File(info.path).exists(), isTrue);
    });

    test('veritabanı dosyasının üzerine yazmayı reddeder', () async {
      await expectLater(
        env.service.createBackup(BackupKind.manual, targetPath: env.dbPath),
        throwsA(
          isA<AppException>()
              .having((e) => e.kind, 'kind', AppErrorKind.validation),
        ),
      );
      // Veritabanı hâlâ sağlam ve kullanılabilir.
      expect(await env.database.integrityCheck(), isTrue);
      expect(await env.database.db.query('customers'), hasLength(1));
    });

    test('aynı saniyede alınan iki yedek birbirinin üzerine yazılmaz',
        () async {
      final a = await env.service.createBackup(BackupKind.auto);
      final b = await env.service.createBackup(BackupKind.auto);

      expect(a.path, isNot(b.path));
      expect(b.name, 'cari_takip_2026-09-29_182500_2.db');
      expect(await backupNames(), hasLength(2));
    });

    test(
        'klasör yolu verildiğinde geçici dosya bırakılmaz ve dosya klasöre yazılır',
        () async {
      final target = p.join(env.dir.path, 'hedef_dizin');
      await Directory(target).create();

      final info = await env.service.createBackup(
        BackupKind.manual,
        targetPath: target,
      );

      expect(p.dirname(info.path), target);
      expect(await File('$target.part').exists(), isFalse);
    });

    test('hedef klasör yazılamıyorsa net bir klasör izni hatası verir',
        () async {
      final fileParent = File(p.join(env.dir.path, 'parent_is_file'));
      await fileParent.writeAsString('not a directory');
      final target = p.join(fileParent.path, 'backup.db');

      await expectLater(
        env.service.createBackup(BackupKind.manual, targetPath: target),
        throwsA(
          isA<AppException>().having(
              (e) => e.message, 'message', contains('Klasör izinlerini')),
        ),
      );
    });
  });

  group('günlük otomatik yedek', () {
    test('günde yalnızca bir kez alınır', () async {
      final first = await env.service.runDailyBackupIfNeeded();
      expect(first, isNotNull);

      env.clock = env.clock.add(const Duration(hours: 3));
      expect(await env.service.runDailyBackupIfNeeded(), isNull);
      expect(await backupNames(), hasLength(1));
    });

    test('ertesi gün yeni yedek alınır', () async {
      await env.service.runDailyBackupIfNeeded();

      env.clock = DateTime(2026, 9, 30, 18, 25);
      final next = await env.service.runDailyBackupIfNeeded();

      expect(next, isNotNull);
      expect(next!.name, 'cari_takip_2026-09-30_182500.db');
      expect(await backupNames(), hasLength(2));
    });

    test('aynı günkü manuel yedek otomatik yedeği engellemez', () async {
      await env.service.createBackup(BackupKind.manual);

      final auto = await env.service.runDailyBackupIfNeeded();

      expect(auto, isNotNull);
      expect(auto!.kind, BackupKind.auto);
    });
  });

  group('retention', () {
    test('son 30 otomatik yedek saklanır, eskileri silinir', () async {
      for (var i = 0; i < 35; i++) {
        env.clock = DateTime(2026, 8, 1 + i, 12);
        await env.service.createBackup(BackupKind.auto);
      }

      final deleted = await env.service.applyRetention();

      expect(deleted, 5);
      final names = await backupNames();
      expect(names, hasLength(30));
      // En eski 5 gün (1-5 Ağustos) silinmiş, 6 Ağustos kalmıştır.
      expect(names.last, 'cari_takip_2026-08-06_120000.db');
      expect(names.first, 'cari_takip_2026-09-04_120000.db');
    });

    test('manuel, geri yükleme öncesi ve ilgisiz dosyalara dokunmaz', () async {
      env.clock = DateTime(2025);
      final manual = await env.service.createBackup(BackupKind.manual);
      final safety = await env.service.createBackup(BackupKind.preRestore);
      final notes = File(p.join(env.backupDirectory.path, 'notlarim.txt'));
      await notes.writeAsString('önemli');

      for (var i = 0; i < 32; i++) {
        env.clock = DateTime(2026, 1, 1 + i);
        await env.service.createBackup(BackupKind.auto);
      }
      await env.service.applyRetention();

      expect(await File(manual.path).exists(), isTrue);
      expect(await File(safety.path).exists(), isTrue);
      expect(await notes.exists(), isTrue);
      expect(
        (await env.service.listBackups())
            .where((b) => b.kind == BackupKind.auto),
        hasLength(30),
      );
    });

    test('günlük yedek, sınırı aşınca eskileri otomatik temizler', () async {
      final service = BackupService(
        database: env.database,
        backupDirectory: env.backupDirectory,
        now: () => env.clock,
        retentionCount: 2,
      );
      for (var i = 0; i < 4; i++) {
        env.clock = DateTime(2026, 9, 1 + i, 9);
        await service.runDailyBackupIfNeeded();
      }

      final names = (await service.listBackups()).map((b) => b.name).toList();
      expect(names, [
        'cari_takip_2026-09-04_090000.db',
        'cari_takip_2026-09-03_090000.db',
      ]);
    });
  });

  group('listBackups', () {
    test('dizin yoksa boş liste döner', () async {
      expect(await env.service.listBackups(), isEmpty);
    });

    test('yeniden eskiye sıralar, türü adından çıkarır, ilgisizleri yok sayar',
        () async {
      env.clock = DateTime(2026, 9, 1, 8);
      await env.service.createBackup(BackupKind.auto);
      env.clock = DateTime(2026, 9, 3, 8);
      await env.service.createBackup(BackupKind.manual);
      env.clock = DateTime(2026, 9, 2, 8);
      await env.service.createBackup(BackupKind.preRestore);
      await File(p.join(env.backupDirectory.path, 'baska.db'))
          .writeAsString('x');
      await File(p.join(env.backupDirectory.path, 'x.db.part'))
          .writeAsString('x');

      final list = await env.service.listBackups();

      expect(list.map((b) => b.kind), [
        BackupKind.manual,
        BackupKind.preRestore,
        BackupKind.auto,
      ]);
      expect(list.first.createdAt, DateTime(2026, 9, 3, 8));
    });
  });

  test('suggestedFileName beklenen biçimi üretir', () {
    final t = DateTime(2026, 1, 5, 7, 4, 9);
    expect(
      BackupService.suggestedFileName(BackupKind.auto, t),
      'cari_takip_2026-01-05_070409.db',
    );
    expect(
      BackupService.suggestedFileName(BackupKind.manual, t),
      'cari_takip_manual_2026-01-05_070409.db',
    );
  });

  test('AppDatabase açıkken aynı dosyadan ayrı bir bağlantı yedeği okuyabilir',
      () async {
    final info = await env.service.createBackup(BackupKind.manual);
    final other = await AppDatabase.open(path: info.path);
    try {
      expect(await other.db.query('customers'), hasLength(1));
      expect(await other.integrityCheck(), isTrue);
    } finally {
      await other.close();
    }
  });

  test('güncelleme öncesi yedek türü adından tanınır ve retention silmez',
      () async {
    env.clock = DateTime(2025);
    final migration = await env.service.createBackup(BackupKind.preMigration);
    expect(migration.name, 'cari_takip_pre-migration_2025-01-01_000000.db');

    for (var i = 0; i < 32; i++) {
      env.clock = DateTime(2026, 1, 1 + i);
      await env.service.createBackup(BackupKind.auto);
    }
    await env.service.applyRetention();

    final listed = await env.service.listBackups();
    expect(
      listed.where((b) => b.kind == BackupKind.preMigration).single.path,
      migration.path,
    );
    expect(await File(migration.path).exists(), isTrue);
    expect(BackupKind.preMigration.label, 'Güncelleme öncesi');
  });
}
