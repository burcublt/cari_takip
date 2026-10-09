import 'package:cari_takip/app/restart_scope.dart';
import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/backup_service.dart';
import 'package:cari_takip/core/backup/restore_service.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/file_size.dart';
import 'package:cari_takip/core/widgets/confirmation_dialog.dart';
import 'package:cari_takip/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup({required bool chooseLocation}) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);

    String? target;
    if (chooseLocation) {
      target = await ref.read(backupFileChooserProvider).chooseSaveLocation(
            suggestedName: BackupService.suggestedFileName(BackupKind.manual),
          );
      if (target == null || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final info = await service.createBackup(
        BackupKind.manual,
        targetPath: target,
      );
      ref.invalidate(backupListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Yedek oluşturuldu: ${info.name}')),
      );
    } on Object catch (error, stack) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.userMessage(error, stackTrace: stack)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final path = await ref.read(backupFileChooserProvider).chooseBackupFile();
    if (path == null || !mounted) return;

    final service = ref.read(restoreServiceProvider);

    // 1) Dosyayı doğrula (veriye dokunmaz).
    setState(() => _busy = true);
    final BackupFileInfo info;
    try {
      info = await service.validate(path);
    } on Object catch (error, stack) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _showMessage(
        'Geçersiz yedek dosyası',
        ErrorMapper.userMessage(error, stackTrace: stack),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    // 2) Ciddi onay.
    final confirmed = await confirmRestoreBackup(
      context,
      details: 'Yedek dosyası: ${p.basename(path)}\n'
          'İçerik: ${info.customerCount} cari, '
          '${info.transactionCount} finans hareketi',
    );
    if (!confirmed || !mounted) return;

    // 3) Geri yükle.
    setState(() => _busy = true);
    try {
      await service.restore(path);
    } on Object catch (error, stack) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _showMessage(
        'Geri yükleme başarısız',
        ErrorMapper.userMessage(error, stackTrace: stack),
      );
      // Bağlantı kapatılıp yeniden açıldıysa eski repository'ler geçersizdir.
      if (!mounted) return;
      if (error is RestoreException && error.requiresRestart) {
        AppRestartScope.restart(context);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    await _showMessage(
      'Geri yükleme tamamlandı',
      'Yedek başarıyla yüklendi. Uygulama verileri yeniden yükleniyor.',
    );
    if (!mounted) return;
    AppRestartScope.restart(context);
  }

  Future<void> _checkIntegrity() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await ref.read(integrityCheckerProvider)();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Veritabanı kontrolü başarılı: sorun bulunamadı.'
                : 'Veritabanında sorun tespit edildi. Hemen yedek almanız '
                    'önerilir.',
          ),
        ),
      );
    } on Object catch (error, stack) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.userMessage(error, stackTrace: stack)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Ayarlar', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        _buildBackupCard(theme),
        const SizedBox(height: 16),
        _buildSystemCard(theme),
        const SizedBox(height: 16),
        Text(
          'Veriler yalnızca bu bilgisayarda saklanır, hiçbir yere gönderilmez. '
          'Yedek dosyaları vergi numarası, telefon ve finans verisi içerdiği '
          'için hassas kabul edilmeli ve güvenli bir yerde saklanmalıdır.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildBackupCard(ThemeData theme) {
    final backups = ref.watch(backupListProvider);
    final list = backups.value ?? const <BackupInfo>[];

    final lastText = backups.hasError
        ? 'Yedek bilgisi okunamadı.'
        : list.isEmpty
            ? 'Henüz yedek alınmadı.'
            : 'Son yedek: ${AppDate.formatDateTime(list.first.createdAt)} '
                '(${list.first.kind.label})';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yedekleme', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
            ],
            Text(lastText, key: const Key('last-backup')),
            const SizedBox(height: 4),
            Text(
              'Otomatik yedek günde bir kez, uygulama açılışında alınır; son '
              '30 otomatik yedek saklanır. Manuel yedekler silinmez.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed:
                      _busy ? null : () => _createBackup(chooseLocation: false),
                  child: const Text('Yedek Oluştur'),
                ),
                OutlinedButton(
                  onPressed:
                      _busy ? null : () => _createBackup(chooseLocation: true),
                  child: const Text('Konum Seçerek Yedekle'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('Yedekten Geri Yükle'),
                ),
              ],
            ),
            if (list.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Son yedekler', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final backup in list.take(8)) _BackupRow(backup: backup),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCard(ThemeData theme) {
    final info = ref.watch(systemInfoProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sistem Bilgileri', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            info.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text(
                ErrorMapper.userMessage(error, stackTrace: stack),
              ),
              data: (value) => Column(
                children: [
                  _InfoRow('Veri klasörü', value.dataDirectory),
                  _InfoRow('Yedek klasörü', value.backupDirectory),
                  _InfoRow(
                    'Veritabanı boyutu',
                    formatFileSize(value.databaseSizeBytes),
                  ),
                  _InfoRow('Şema sürümü', 'v${value.schemaVersion}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _checkIntegrity,
              child: const Text('Veritabanı Kontrolü'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.backup});

  final BackupInfo backup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(backup.name, overflow: TextOverflow.ellipsis),
          ),
          Expanded(child: Text(backup.kind.label)),
          SizedBox(width: 90, child: Text(formatFileSize(backup.sizeBytes))),
          SizedBox(
            width: 130,
            child: Text(
              AppDate.formatDateTime(backup.createdAt),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
