import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

/// Yedek dosyası seçim/kaydetme diyaloglarını UI'dan ayırır (test edilebilirlik).
abstract interface class BackupFileChooser {
  /// Yedeğin kaydedileceği yolu seçtirir; vazgeçilirse `null`.
  Future<String?> chooseSaveLocation({required String suggestedName});

  /// Geri yüklenecek yedek dosyasını seçtirir; vazgeçilirse `null`.
  Future<String?> chooseBackupFile();
}

class FileSelectorBackupChooser implements BackupFileChooser {
  const FileSelectorBackupChooser();

  static const _typeGroup = XTypeGroup(
    label: 'Cari Takip yedeği',
    extensions: ['db'],
  );

  @override
  Future<String?> chooseSaveLocation({required String suggestedName}) async {
    final directory = await getDirectoryPath(
      confirmButtonText: 'Yedek klasörünü seç',
    );
    if (directory == null) return null;
    return p.join(directory, suggestedName);
  }

  @override
  Future<String?> chooseBackupFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [_typeGroup],
      confirmButtonText: 'Seç',
    );
    return file?.path;
  }
}
