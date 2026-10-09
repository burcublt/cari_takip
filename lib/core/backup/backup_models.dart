enum BackupKind {
  /// Günde en fazla bir kez otomatik alınır; son 30 tanesi saklanır.
  auto,

  /// Kullanıcının "Yedek Oluştur" ile aldığı yedek; otomatik silinmez.
  manual,

  /// Geri yüklemeden hemen önce alınan güvenlik yedeği; otomatik silinmez.
  preRestore,

  /// Uygulama güncellemesi veritabanı şemasını değiştirmeden önce alınan
  /// güvenlik yedeği; otomatik silinmez.
  preMigration;

  String get label => switch (this) {
        BackupKind.auto => 'Otomatik',
        BackupKind.manual => 'Manuel',
        BackupKind.preRestore => 'Geri yükleme öncesi',
        BackupKind.preMigration => 'Güncelleme öncesi',
      };
}

class BackupInfo {
  const BackupInfo({
    required this.path,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final BackupKind kind;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Doğrulanmış bir yedek dosyasının özeti.
class BackupFileInfo {
  const BackupFileInfo({
    required this.schemaVersion,
    required this.customerCount,
    required this.transactionCount,
  });

  final int schemaVersion;
  final int customerCount;
  final int transactionCount;
}
