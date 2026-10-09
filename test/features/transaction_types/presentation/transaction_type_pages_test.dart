import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dashboard_repository.dart';
import '../../../helpers/fake_transaction_type_repository.dart';

Future<FakeTransactionTypeRepository> _pumpTypes(
  WidgetTester tester, {
  List<TransactionType>? types,
  FakeTransactionTypeRepository? repository,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = repository ?? FakeTransactionTypeRepository(types);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository()),
        transactionTypeRepositoryProvider.overrideWithValue(repo),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('İşlem Tipleri'),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tapSegment(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<TransactionTypeStatusFilter>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openNewForm(WidgetTester tester) async {
  await tester.tap(find.text('Yeni İşlem Tipi'));
  await tester.pumpAndSettle();
}

void main() {
  group('liste', () {
    testWidgets('tip yoksa empty state ve yönlendirme gösterir', (t) async {
      await _pumpTypes(t);

      expect(find.text('Henüz işlem tipi eklenmedi.'), findsOneWidget);
      await t.tap(find.text('Yeni İşlem Tipi Ekle'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('field-name')), findsOneWidget);
    });

    testWidgets('varsayılan olarak aktif tipleri listeler, filtre çalışır',
        (t) async {
      await _pumpTypes(
        t,
        types: [
          makeType(),
          makeType(id: 2, name: 'Vergi'),
          makeType(id: 3, name: 'Eski Tip', isActive: false),
        ],
      );

      expect(find.text('Kira'), findsOneWidget);
      expect(find.text('Vergi'), findsOneWidget);
      expect(find.text('Eski Tip'), findsNothing);

      await _tapSegment(t, 'Pasif');
      expect(find.text('Eski Tip'), findsOneWidget);
      expect(find.text('Kira'), findsNothing);

      await _tapSegment(t, 'Tümü');
      expect(find.text('Eski Tip'), findsOneWidget);
      expect(find.text('Kira'), findsOneWidget);
    });

    testWidgets('pasif tip yoksa pasif filtresinde mesaj gösterir', (t) async {
      await _pumpTypes(t, types: [makeType()]);
      await _tapSegment(t, 'Pasif');
      expect(find.text('Pasif işlem tipi bulunmuyor.'), findsOneWidget);
    });

    testWidgets('pasife alma onay ister ve tipi aktif listeden çıkarır',
        (t) async {
      final repo = await _pumpTypes(t, types: [makeType()]);

      await t.tap(find.byTooltip('Pasife Al'));
      await t.pumpAndSettle();
      expect(find.text('İşlem tipi pasife alınsın mı?'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Pasife Al'));
      await t.pumpAndSettle();

      expect(repo.types.single.isActive, isFalse);
      expect(find.text('İşlem tipi pasife alındı.'), findsOneWidget);
      expect(find.text('Kira'), findsNothing);
    });

    testWidgets('pasife almaktan vazgeçilirse tip aktif kalır', (t) async {
      final repo = await _pumpTypes(t, types: [makeType()]);

      await t.tap(find.byTooltip('Pasife Al'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();

      expect(repo.types.single.isActive, isTrue);
      expect(find.text('Kira'), findsOneWidget);
    });

    testWidgets('pasif tip onaysız tekrar aktif edilir', (t) async {
      final repo = await _pumpTypes(
        t,
        types: [makeType(isActive: false)],
      );
      await _tapSegment(t, 'Pasif');

      await t.tap(find.byTooltip('Aktif Et'));
      await t.pumpAndSettle();

      expect(repo.types.single.isActive, isTrue);
      expect(find.text('İşlem tipi aktif edildi.'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('boş ad ile kaydedilemez', (t) async {
      final repo = await _pumpTypes(t);
      await _openNewForm(t);

      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(find.text('İşlem tipi adı zorunludur.'), findsOneWidget);
      expect(repo.types, isEmpty);
    });

    testWidgets('yeni tip kaydedilir ve listede görünür', (t) async {
      final repo = await _pumpTypes(t);
      await _openNewForm(t);

      await t.enterText(find.byKey(const Key('field-name')), '  Aidat  ');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(repo.types.single.name, 'Aidat');
      expect(find.text('İşlem tipi kaydedildi.'), findsOneWidget);
      expect(find.text('Aidat'), findsOneWidget);
    });

    testWidgets('aynı isimde tip eklenirse alan altında uyarı gösterir',
        (t) async {
      final repo = await _pumpTypes(t, types: [makeType()]);
      await _openNewForm(t);

      await t.enterText(find.byKey(const Key('field-name')), 'KİRA');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(find.text('Bu isimde bir işlem tipi zaten mevcut.'), findsOneWidget);
      expect(repo.types, hasLength(1));
      expect(find.byKey(const Key('field-name')), findsOneWidget);
    });

    testWidgets('yazmaya devam edince duplicate uyarısı kalkar', (t) async {
      await _pumpTypes(t, types: [makeType()]);
      await _openNewForm(t);

      await t.enterText(find.byKey(const Key('field-name')), 'Kira');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(find.text('Bu isimde bir işlem tipi zaten mevcut.'), findsOneWidget);

      await t.enterText(find.byKey(const Key('field-name')), 'Kira 2');
      await t.pumpAndSettle();
      expect(find.text('Bu isimde bir işlem tipi zaten mevcut.'), findsNothing);
    });

    testWidgets('düzenleme mevcut adla açılır ve yeniden adlandırır', (t) async {
      final repo = await _pumpTypes(t, types: [makeType()]);

      await t.tap(find.byTooltip('Düzenle'));
      await t.pumpAndSettle();

      expect(find.text('İşlem Tipi Düzenle'), findsOneWidget);
      final field =
          t.widget<TextFormField>(find.byKey(const Key('field-name')));
      expect(field.controller!.text, 'Kira');

      await t.enterText(find.byKey(const Key('field-name')), 'Ofis Kirası');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(repo.types.single.name, 'Ofis Kirası');
      expect(find.text('Ofis Kirası'), findsOneWidget);
    });

    testWidgets('tek alanlı formda Enter kaydeder', (t) async {
      final repo = await _pumpTypes(t);
      await _openNewForm(t);

      await t.enterText(find.byKey(const Key('field-name')), 'Aidat');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();

      expect(repo.types.single.name, 'Aidat');
    });

    testWidgets('Esc ile vazgeçilir ve kayıt oluşmaz', (t) async {
      final repo = await _pumpTypes(t);
      await _openNewForm(t);
      await t.enterText(find.byKey(const Key('field-name')), 'Aidat');

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();

      expect(repo.types, isEmpty);
      expect(find.byKey(const Key('field-name')), findsNothing);
      expect(find.text('Henüz işlem tipi eklenmedi.'), findsOneWidget);
    });

    testWidgets('Ctrl+Enter ile kaydedilir', (t) async {
      final repo = await _pumpTypes(t);
      await _openNewForm(t);
      await t.enterText(find.byKey(const Key('field-name')), 'Aidat');

      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();

      expect(repo.types.single.name, 'Aidat');
    });

    testWidgets('yükleme hatasında Tekrar Dene ile form açılır', (t) async {
      final repo = _FlakyTypeRepository([makeType()]);
      await _pumpTypes(t, repository: repo);

      await t.tap(find.byTooltip('Düzenle'));
      await t.pumpAndSettle();
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.byKey(const Key('field-name')), findsNothing);

      await t.tap(find.text('Tekrar Dene'));
      await t.pumpAndSettle();

      expect(find.text('İşlem Tipi Düzenle'), findsOneWidget);
      expect(find.byKey(const Key('field-name')), findsOneWidget);
    });

    testWidgets('başka tipin adına yeniden adlandırma reddedilir', (t) async {
      final repo = await _pumpTypes(
        t,
        types: [makeType(), makeType(id: 2, name: 'Vergi')],
      );

      await t.tap(find.byTooltip('Düzenle').first);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('field-name')), 'vergi');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(find.text('Bu isimde bir işlem tipi zaten mevcut.'), findsOneWidget);
      expect(repo.types.firstWhere((x) => x.id == 1).name, 'Kira');
    });
  });
}

/// İlk `getTransactionTypeById` çağrısında hata veren sahte repository.
class _FlakyTypeRepository extends FakeTransactionTypeRepository {
  _FlakyTypeRepository(super.initial);

  int failures = 1;

  @override
  Future<TransactionType?> getTransactionTypeById(int id) async {
    if (failures > 0) {
      failures--;
      throw const AppException(
        AppErrorKind.storage,
        'Veritabanı işlemi tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }
    return super.getTransactionTypeById(id);
  }
}
