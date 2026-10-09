import 'package:cari_takip/core/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dialogu bir butonla açar; sonucu [result] içine yazar.
Future<void> _open(
  WidgetTester tester,
  Future<bool> Function(BuildContext context) opener,
  List<bool?> result,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async => result.add(await opener(context)),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onaylanınca true döner', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => showConfirmationDialog(
        context,
        title: 'Başlık',
        message: 'Mesaj',
        confirmLabel: 'Evet',
      ),
      result,
    );

    expect(find.text('Başlık'), findsOneWidget);
    expect(find.text('Mesaj'), findsOneWidget);

    await tester.tap(find.text('Evet'));
    await tester.pumpAndSettle();
    expect(result, [true]);
  });

  testWidgets('vazgeçilince false döner', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => showConfirmationDialog(
        context,
        title: 'Başlık',
        message: 'Mesaj',
      ),
      result,
    );

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(result, [false]);
  });

  testWidgets('dışarı tıklamak dialogu kapatmaz', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => showConfirmationDialog(
        context,
        title: 'Başlık',
        message: 'Mesaj',
      ),
      result,
    );

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('Başlık'), findsOneWidget);
    expect(result, isEmpty);
  });

  testWidgets('hareket silme onayı Sil ile true döner', (tester) async {
    final result = <bool?>[];
    await _open(tester, confirmDeleteTransaction, result);

    expect(find.textContaining('silmek istediğinize emin misiniz'),
        findsOneWidget);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(result, [true]);
  });

  testWidgets('cari pasife alma onayı adı gösterir', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => confirmDeactivateCustomer(context, 'Yılmaz Ltd.'),
      result,
    );

    expect(find.textContaining('Yılmaz Ltd.'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(result, [false]);
  });

  testWidgets('restore onayı kutu işaretlenmeden etkinleşmez', (tester) async {
    final result = <bool?>[];
    await _open(tester, confirmRestoreBackup, result);

    final restoreButton = find.widgetWithText(FilledButton, 'Geri Yükle');
    expect(tester.widget<FilledButton>(restoreButton).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(restoreButton).onPressed, isNotNull);

    await tester.tap(restoreButton);
    await tester.pumpAndSettle();
    expect(result, [true]);
  });

  testWidgets('restore onayında vazgeçilince false döner', (tester) async {
    final result = <bool?>[];
    await _open(tester, confirmRestoreBackup, result);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(result, [false]);
  });

  testWidgets('restore onayı verilen ayrıntıyı gösterir', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => confirmRestoreBackup(
        context,
        details: 'Yedek dosyası: yedek.db\nİçerik: 3 cari, 12 hareket',
      ),
      result,
    );

    expect(find.textContaining('yedek.db'), findsOneWidget);
    expect(find.textContaining('3 cari, 12 hareket'), findsOneWidget);
  });

  testWidgets('Esc onay dialogunu vazgeç olarak kapatır', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => showConfirmationDialog(
        context,
        title: 'Başlık',
        message: 'Mesaj',
        destructive: true,
      ),
      result,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Başlık'), findsNothing);
    expect(result, [false]);
  });

  testWidgets('Enter yıkıcı onayı kendiliğinden vermez', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      (context) => showConfirmationDialog(
        context,
        title: 'Başlık',
        message: 'Mesaj',
        destructive: true,
      ),
      result,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Başlık'), findsOneWidget);
    expect(result, isEmpty);
  });

  testWidgets('Esc restore onayını vazgeç olarak kapatır', (tester) async {
    final result = <bool?>[];
    await _open(tester, confirmRestoreBackup, result);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Yedekten geri yüklensin mi?'), findsNothing);
    expect(result, [false]);
  });
}
