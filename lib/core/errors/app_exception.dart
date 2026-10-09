enum AppErrorKind { validation, duplicate, inUse, notFound, storage, unknown }

/// Kullanıcıya gösterilebilir mesaj taşıyan uygulama hatası.
/// [cause] ve [stackTrace] yalnızca teknik log içindir, UI'da gösterilmez.
class AppException implements Exception {
  const AppException(
    this.kind,
    this.message, {
    this.cause,
    this.stackTrace,
  });

  final AppErrorKind kind;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException(${kind.name}): $message';
}
