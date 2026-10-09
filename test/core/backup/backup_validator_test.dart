import 'dart:io';

import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_validator.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/backup_test_env.dart';

Matcher _invalid([String text = '']) => isA<AppException>()
    .having((e) => e.kind, 'kind', AppErrorKind.validation)
    .having((e) => e.message, 'message', contains(text));

void main() {
  late BackupTestEnv env;
  late String validBackup;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    env = await BackupTestEnv.create();
    final ali = await env.addCustomer('Ali');
    await env.addTransaction(ali, 125050);
    await env.addTransaction(ali, 100);
    validBackup = (await env.service.createBackup(
      BackupKind.manual,
    ))
        .path;
  });

  tearDown(() => env.dispose());

  Future<String> copyOfValid(String name) async {
    final path = p.join(env.dir.path, name);
    await File(validBackup).copy(path);
    return path;
  }

  Future<void> validate(String path, {int latest = 1}) =>
      BackupValidator.validate(path, latestSchemaVersion: latest);

  test('geçerli yedek kabul edilir ve özeti döner', () async {
    final info = await BackupValidator.validate(
      validBackup,
      latestSchemaVersion: 1,
    );
    expect(info.schemaVersion, 1);
    expect(info.customerCount, 1);
    expect(info.transactionCount, 2);
  });

  test('olmayan dosya reddedilir', () async {
    await expectLater(
      validate(p.join(env.dir.path, 'yok.db')),
      throwsA(_invalid('bulunamadı')),
    );
  });

  test('SQLite olmayan dosya reddedilir', () async {
    final path = p.join(env.dir.path, 'metin.db');
    await File(path).writeAsString('bu bir veritabanı değil, düz metin');
    await expectLater(validate(path), throwsA(_invalid('SQLite')));
  });

  test('16 bayttan küçük dosya reddedilir', () async {
    final path = p.join(env.dir.path, 'kisa.db');
    await File(path).writeAsBytes([1, 2, 3]);
    await expectLater(validate(path), throwsA(_invalid('SQLite')));
  });

  test('boş dosya reddedilir', () async {
    final path = p.join(env.dir.path, 'bos.db');
    await File(path).writeAsBytes([]);
    await expectLater(validate(path), throwsA(_invalid()));
  });

  test('başka bir uygulamanın SQLite dosyası reddedilir', () async {
    final path = p.join(env.dir.path, 'baska.db');
    await mutateDatabase(path, (db) async {
      await db.execute('CREATE TABLE notlar (id INTEGER PRIMARY KEY)');
      await db.execute('PRAGMA user_version = 1');
    });
    await expectLater(validate(path), throwsA(_invalid('Cari Takip yedeği')));
  });

  test('user_version 0 olan SQLite dosyası reddedilir', () async {
    final path = p.join(env.dir.path, 'surumsuz.db');
    await mutateDatabase(path, (db) async {
      await db.execute('CREATE TABLE x (id INTEGER)');
    });
    await expectLater(validate(path), throwsA(_invalid('Cari Takip yedeği')));
  });

  test('uygulamadan daha yeni şema sürümü reddedilir', () async {
    final path = await copyOfValid('yeni.db');
    await mutateDatabase(path, (db) => db.execute('PRAGMA user_version = 99'));
    await expectLater(validate(path), throwsA(_invalid('daha yeni')));
  });

  test('gerekli kolonu eksik tablo reddedilir', () async {
    final path = await copyOfValid('eksik_kolon.db');
    await mutateDatabase(path, (db) async {
      await db.execute('DROP TABLE financial_transactions');
      await db.execute(
        'CREATE TABLE financial_transactions (id INTEGER PRIMARY KEY)',
      );
    });
    await expectLater(validate(path), throwsA(_invalid('gerekli tablolar')));
  });

  test('tablosu silinmiş dosya reddedilir', () async {
    final path = await copyOfValid('tablosuz.db');
    await mutateDatabase(path, (db) async {
      await db.execute('DROP TABLE financial_transactions');
    });
    await expectLater(validate(path), throwsA(_invalid('gerekli tablolar')));
  });

  test('foreign key tutarsızlığı olan dosya reddedilir', () async {
    final path = await copyOfValid('fk.db');
    await mutateDatabase(path, (db) async {
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
    await expectLater(validate(path), throwsA(_invalid('tutarsız')));
  });

  test('bozulmuş dosya AppException ile reddedilir (çökmez)', () async {
    final path = await copyOfValid('bozuk.db');
    final bytes = await File(path).readAsBytes();
    for (var i = 4096; i < bytes.length; i++) {
      bytes[i] = 0xFF;
    }
    await File(path).writeAsBytes(bytes);

    await expectLater(validate(path), throwsA(isA<AppException>()));
  });

  test('kesilmiş (yarım) dosya AppException ile reddedilir', () async {
    final path = await copyOfValid('yarim.db');
    final bytes = await File(path).readAsBytes();
    await File(path).writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

    await expectLater(validate(path), throwsA(isA<AppException>()));
  });

  test('doğrulama dosyayı değiştirmez', () async {
    final before = await File(validBackup).readAsBytes();
    await validate(validBackup);
    final after = await File(validBackup).readAsBytes();
    expect(after, before);
  });
}
