import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Onay dialogu. Onaylanırsa `true`; vazgeçilirse `false` döner.
/// Dışarı tıklayarak kapatılamaz, böylece yanlışlıkla onaylanmaz/iptal olmaz.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _CancelOnEscape(
      onCancel: () => Navigator.of(dialogContext).pop(false),
      child: AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive ? _destructiveStyle(dialogContext) : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

Future<bool> confirmDeleteTransaction(BuildContext context) {
  return showConfirmationDialog(
    context,
    title: 'Finans hareketi silinsin mi?',
    message: 'Bu finans hareketini silmek istediğinize emin misiniz? '
        'Bu işlem geri alınamaz.',
    confirmLabel: 'Sil',
    destructive: true,
  );
}

Future<bool> confirmDeactivateCustomer(BuildContext context, String name) {
  return showConfirmationDialog(
    context,
    title: 'Cari pasife alınsın mı?',
    message: '"$name" pasife alınacak. Geçmiş hareketleri ve raporları '
        'korunur; yeni hareket girişinde varsayılan olarak listelenmez.',
    confirmLabel: 'Pasife Al',
    destructive: true,
  );
}

Future<bool> confirmDeactivateTransactionType(
  BuildContext context,
  String name,
) {
  return showConfirmationDialog(
    context,
    title: 'İşlem tipi pasife alınsın mı?',
    message: '"$name" pasife alınacak. Eski hareketlerde görünmeye devam eder; '
        'yeni hareket girişinde varsayılan olarak listelenmez.',
    confirmLabel: 'Pasife Al',
    destructive: true,
  );
}

/// Yedekten geri yükleme için daha güçlü uyarı: kullanıcı riski onaylamadan
/// "Geri Yükle" butonu etkinleşmez.
Future<bool> confirmRestoreBackup(
  BuildContext context, {
  String? details,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RestoreDialog(details: details),
  );
  return result ?? false;
}

/// Esc tuşu diyalogu "vazgeç" olarak kapatır. Odak diyalogun kendisinde
/// başlar; böylece Enter yanlışlıkla yıkıcı bir onayı vermez.
class _CancelOnEscape extends StatelessWidget {
  const _CancelOnEscape({required this.onCancel, required this.child});

  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: Focus(autofocus: true, child: child),
    );
  }
}

ButtonStyle _destructiveStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: scheme.error,
    foregroundColor: scheme.onError,
  );
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({this.details});

  /// Seçilen yedeğin özeti (dosya adı, kayıt sayıları).
  final String? details;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return _CancelOnEscape(
      onCancel: () => Navigator.of(context).pop(false),
      child: AlertDialog(
        title: const Text('Yedekten geri yüklensin mi?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details != null) ...[
                Text(
                  details,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Mevcut tüm veriler seçtiğiniz yedekteki verilerle '
                'değiştirilecek. Yedeğin alındığı tarihten sonra girilen '
                'kayıtlar kaybolacaktır.\n\n'
                'İşlemden önce mevcut verinin otomatik bir yedeği alınır.',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _understood,
                onChanged: (value) =>
                    setState(() => _understood = value ?? false),
                title: const Text('Mevcut verilerin değiştirileceğini anlıyorum.'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: _destructiveStyle(context),
            onPressed:
                _understood ? () => Navigator.of(context).pop(true) : null,
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );
  }
}
