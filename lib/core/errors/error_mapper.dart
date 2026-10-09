import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite/plugin hatalarını kullanıcı dostu [AppException]'a çevirir.
/// Ham hata mesajı kullanıcıya gösterilmez; yalnızca debug logunda görünür.
abstract final class ErrorMapper {
  static const defaultDuplicateMessage = 'Bu kayıt zaten mevcut.';
  static const defaultInUseMessage =
      'Bu kayıt başka kayıtlarla ilişkili olduğu için işlem tamamlanamadı.';
  static const storageMessage =
      'Veritabanı işlemi tamamlanamadı. Lütfen tekrar deneyin.';
  static const unknownMessage = 'Beklenmeyen bir hata oluştu.';

  /// [duplicateMessage] / [inUseMessage] ile çağıran yer kendi bağlamına özel
  /// mesajı verebilir (ör. `Bu isimde bir işlem tipi zaten mevcut.`).
  static AppException map(
    Object error, {
    StackTrace? stackTrace,
    String? duplicateMessage,
    String? inUseMessage,
  }) {
    if (error is AppException) return error;

    _log(error, stackTrace);

    if (error is DatabaseException) {
      final text = error.toString();
      if (text.contains('UNIQUE constraint failed')) {
        return AppException(
          AppErrorKind.duplicate,
          duplicateMessage ?? defaultDuplicateMessage,
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (text.contains('FOREIGN KEY constraint failed')) {
        return AppException(
          AppErrorKind.inUse,
          inUseMessage ?? defaultInUseMessage,
          cause: error,
          stackTrace: stackTrace,
        );
      }
      return AppException(
        AppErrorKind.storage,
        storageMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      AppErrorKind.unknown,
      unknownMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// UI'da gösterilecek güvenli mesaj.
  static String userMessage(Object error, {StackTrace? stackTrace}) =>
      map(error, stackTrace: stackTrace).message;

  static void _log(Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('[AppError] $error\n${stackTrace ?? ''}');
    }
  }
}
