import 'dart:io';

import 'package:path/path.dart' as p;

/// Uygulama veri dizini (platforma özel kod yalnızca burada).
///
/// macOS:   ~/Library/Application Support/CariTakip/
/// Windows: %LOCALAPPDATA%\CariTakip\
abstract final class AppPaths {
  static const _appDirName = 'CariTakip';
  static const databaseFileName = 'cari_takip.db';

  static Directory appDataDirectory() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final base = env['LOCALAPPDATA'];
      if (base == null || base.isEmpty) {
        throw StateError('LOCALAPPDATA ortam değişkeni bulunamadı.');
      }
      return Directory(p.join(base, _appDirName));
    }
    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home == null || home.isEmpty) {
        throw StateError('HOME ortam değişkeni bulunamadı.');
      }
      return Directory(
        p.join(home, 'Library', 'Application Support', _appDirName),
      );
    }
    throw UnsupportedError('Desteklenmeyen platform: ${Platform.operatingSystem}');
  }

  /// Otomatik ve manuel yedeklerin varsayılan dizini (oluşturulmaz).
  static Directory backupDirectory() =>
      Directory(p.join(appDataDirectory().path, 'backups'));

  /// Dizini oluşturur ve veritabanı dosyasının tam yolunu döndürür.
  static Future<String> databasePath() async {
    final dir = appDataDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, databaseFileName);
  }
}
