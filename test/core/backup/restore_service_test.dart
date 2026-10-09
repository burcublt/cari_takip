import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/restore_service.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/backup_test_env.dart';

void main() {
  late BackupTestEnv env;
  late RestoreService restore;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    env = await BackupTestEnv.create();
    restore = RestoreService(database: env.database, backupService: env.service);
  });

  tearDown(() => env.dispose());

  Future<void> seedBase() async {
    final ali = await env.addCustomer('Ali');
    final veli = await env.addCustomer('Veli');
    await env.addTransaction(ali, 125050);
    await env.addTransaction(veli, 100, typeId: 3);
  }

  test('restore sonrası veri yedekle birebir aynıdır', () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);
    final atBackup = await env.dump();

    // Yedekten sonra veri değişir.
    final zeynep = await env.addCustomer('Zeynep');
    await env.addTransaction(zeynep, 999);
    await env.database.db.delete('financial_transactions', where: 'id = 1');
    expect(await env.dump(), isNot(atBackup));

    env.clock = env.clock.add(const Duration(minutes: 1));
    await restore.restore(backup.path);

    expect(await env.dump(), atBackup);
    expect(await env.database.integrityCheck(), isTrue);
    expect(await env.database.foreignKeysEnabled(), isTrue);
    expect(await env.database.schemaVersion(), 1);
  });

  test('restore öncesi mevcut verinin güvenlik yedeği alınır', () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);
    final zeynep = await env.addCustomer('Zeynep');
    await env.addTransaction(zeynep, 999);
    final beforeRestore = await env.dump();

    env.clock = env.clock.add(const Duration(minutes: 1));
    await restore.restore(backup.path);

    final safety = (await env.service.listBackups())
        .where((b) => b.kind == BackupKind.preRestore)
        .single;
    final info = await restore.validate(safety.path);
    expect(info.customerCount, 3);
    expect(info.transactionCount, 3);
    expect(beforeRestore, contains('Zeynep'));
  });

  test('restore sonrası uygulama yeni bağlantıyla çalışmaya devam eder',
      () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);
    await env.addCustomer('Zeynep');

    await restore.restore(backup.path);

    // Yeni bağlantıya yazılabilir; foreign key'ler zorunludur.
    await env.addCustomer('Yeni');
    expect(await env.database.db.query('customers'), hasLength(3));
    await expectLater(
      env.addTransaction(999, 1),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('geçici dosyalar geride bırakılmaz', () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);

    await restore.restore(backup.path);

    expect(await File('${env.dbPath}.restore').exists(), isFalse);
    expect(await File('${env.dbPath}.old').exists(), isFalse);
  });

  test('geçersiz yedek reddedilir; veri ve bağlantı değişmez', () async {
    await seedBase();
    final before = await env.dump();
    final junk = File(p.join(env.dir.path, 'sahte.db'));
    await junk.writeAsString('bu bir yedek değil');

    await expectLater(
      restore.restore(junk.path),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.validation),
      ),
    );

    expect(await env.dump(), before);
    expect(await env.database.integrityCheck(), isTrue);
    // Güvenlik yedeği bile alınmamış olmalı: hiçbir şey başlamadı.
    expect(await env.service.listBackups(), isEmpty);
  });

  test('var olmayan dosya reddedilir', () async {
    await seedBase();
    await expectLater(
      restore.restore(p.join(env.dir.path, 'yok.db')),
      throwsA(isA<AppException>()),
    );
    expect(await env.database.db.query('customers'), hasLength(2));
  });

  test('geçerli veritabanı dosyasının kendisi yedek olarak seçilemez', () async {
    await seedBase();
    await expectLater(
      restore.restore(env.dbPath),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.validation),
      ),
    );
    expect(await env.database.db.query('customers'), hasLength(2));
  });

  test('foreign key tutarsızlığı olan yedek reddedilir', () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);
    await mutateDatabase(backup.path, (db) async {
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.insert('financial_transactions', {
        'customer_id': 999,
        'transaction_type_id': 1,
        'transaction_date': '2026-09-15',
        'amount_kurus': 5,
        'created_at': 'x',
        'updated_at': 'x',
      });
    });
    final before = await env.dump();

    await expectLater(restore.restore(backup.path), throwsA(isA<AppException>()));
    expect(await env.dump(), before);
  });

  test('geri yükleme sonrası kontrol başarısız olursa eski veri geri konur',
      () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);
    final zeynep = await env.addCustomer('Zeynep');
    await env.addTransaction(zeynep, 999);
    final beforeRestore = await env.dump();

    final failing = RestoreService(
      database: env.database,
      backupService: env.service,
      verifyAfterRestore: (_) async => throw StateError('simüle edilen hata'),
    );
    env.clock = env.clock.add(const Duration(minutes: 1));

    await expectLater(
      failing.restore(backup.path),
      throwsA(
        isA<RestoreException>()
            .having((e) => e.requiresRestart, 'requiresRestart', isTrue)
            .having((e) => e.message, 'message', contains('korundu')),
      ),
    );

    // Mevcut veri aynen duruyor ve veritabanı yeniden kullanılabilir.
    expect(await env.dump(), beforeRestore);
    expect(await env.database.integrityCheck(), isTrue);
    await env.addCustomer('Sonradan');
    expect(await env.database.db.query('customers'), hasLength(4));

    expect(await File('${env.dbPath}.restore').exists(), isFalse);
    expect(await File('${env.dbPath}.old').exists(), isFalse);
    expect(
      (await env.service.listBackups())
          .where((b) => b.kind == BackupKind.preRestore),
      hasLength(1),
    );
  });

  test('doğrulama veriye dokunmaz ve özeti döner', () async {
    await seedBase();
    final backup = await env.service.createBackup(BackupKind.manual);
    final before = await env.dump();

    final info = await restore.validate(backup.path);

    expect(info.customerCount, 2);
    expect(info.transactionCount, 2);
    expect(await env.dump(), before);
  });
}
