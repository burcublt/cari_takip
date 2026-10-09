import 'package:cari_takip/core/database/app_database.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _now = '2026-09-29T00:00:00.000Z';

Future<AppException> _mapFailure(
  Future<Object?> Function() action, {
  String? duplicateMessage,
  String? inUseMessage,
}) async {
  try {
    await action();
  } on Object catch (error, stack) {
    return ErrorMapper.map(
      error,
      stackTrace: stack,
      duplicateMessage: duplicateMessage,
      inUseMessage: inUseMessage,
    );
  }
  fail('Hata bekleniyordu.');
}

void main() {
  late AppDatabase appDb;
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    db = appDb.db;
  });

  tearDown(() => appDb.close());

  test('unique ihlali duplicate olarak eşlenir ve özel mesaj kullanılır', () async {
    final error = await _mapFailure(
      () => db.insert('transaction_types', {
        'name': 'kira',
        'is_active': 1,
        'created_at': _now,
        'updated_at': _now,
      }),
      duplicateMessage: 'Bu isimde bir işlem tipi zaten mevcut.',
    );

    expect(error.kind, AppErrorKind.duplicate);
    expect(error.message, 'Bu isimde bir işlem tipi zaten mevcut.');
    expect(error.message, isNot(contains('UNIQUE')));
  });

  test('unique ihlali özel mesaj verilmezse varsayılan mesaj döner', () async {
    final error = await _mapFailure(
      () => db.insert('transaction_types', {
        'name': 'Kira',
        'is_active': 1,
        'created_at': _now,
        'updated_at': _now,
      }),
    );
    expect(error.message, ErrorMapper.defaultDuplicateMessage);
  });

  test('foreign key ihlali inUse olarak eşlenir', () async {
    final error = await _mapFailure(
      () => db.insert('financial_transactions', {
        'customer_id': 999,
        'transaction_type_id': 1,
        'transaction_date': '2026-09-29',
        'amount_kurus': 100,
        'created_at': _now,
        'updated_at': _now,
      }),
    );

    expect(error.kind, AppErrorKind.inUse);
    expect(error.message, isNot(contains('FOREIGN')));
  });

  test('diğer veritabanı hataları storage olarak eşlenir', () async {
    final error = await _mapFailure(() => db.rawQuery('SELECT * FROM yok'));

    expect(error.kind, AppErrorKind.storage);
    expect(error.message, ErrorMapper.storageMessage);
    expect(error.cause, isNotNull);
  });

  test('bilinmeyen hata unknown olarak eşlenir, ham mesaj sızmaz', () {
    final error = ErrorMapper.map(StateError('teknik ayrıntı'));

    expect(error.kind, AppErrorKind.unknown);
    expect(error.message, ErrorMapper.unknownMessage);
    expect(error.message, isNot(contains('teknik')));
  });

  test('AppException olduğu gibi döner', () {
    const original = AppException(AppErrorKind.validation, 'Geçersiz.');
    expect(identical(ErrorMapper.map(original), original), isTrue);
  });

  test('userMessage yalnızca kullanıcı mesajını verir', () {
    expect(
      ErrorMapper.userMessage(StateError('x')),
      ErrorMapper.unknownMessage,
    );
  });
}
