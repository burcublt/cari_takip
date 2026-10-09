import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_customer_repository.dart';
import '../../../helpers/fake_dashboard_repository.dart';
import '../../../helpers/fake_transaction_repository.dart';
import '../../../helpers/fake_transaction_type_repository.dart';

Future<FakeTransactionRepository> _pump(
  WidgetTester tester, {
  List<Customer>? customers,
  List<TransactionType>? types,
  List<FinancialTransaction>? transactions,
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final customerRepo = FakeCustomerRepository(
    customers ??
        [
          makeCustomer(),
          makeCustomer(id: 2, firstName: 'Zeynep', lastName: 'Kaya'),
        ],
  );
  final typeRepo = FakeTransactionTypeRepository(
    types ?? [makeType(), makeType(id: 2, name: 'Vergi')],
  );
  final repo = FakeTransactionRepository(
    customers: customerRepo,
    types: typeRepo,
    initial: transactions,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository()),
        customerRepositoryProvider.overrideWithValue(customerRepo),
        transactionTypeRepositoryProvider.overrideWithValue(typeRepo),
        transactionRepositoryProvider.overrideWithValue(repo),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();

  // Dar/kısa pencerede menü ikon modunda olduğu için ipucu üzerinden dokun.
  await tester.tap(find.byTooltip('Finans Hareketleri'));
  await tester.pumpAndSettle();
  return repo;
}

List<FinancialTransaction> _sample() => [
      makeTransaction(note: 'Eylül kirası'),
      makeTransaction(
        id: 2,
        customerId: 2,
        customerName: 'Zeynep Kaya',
        transactionTypeId: 2,
        transactionTypeName: 'Vergi',
        date: DateTime(2026, 9, 20),
        amountKurus: 50000,
        note: 'KDV',
      ),
    ];

Future<void> _pickCustomer(
  WidgetTester tester,
  Key selectorKey,
  String name,
) async {
  await tester.tap(find.byKey(selectorKey));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(name),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickType(
    WidgetTester tester, Finder dropdown, String name) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('liste', () {
    testWidgets('kayıt yoksa empty state gösterir ve forma yönlendirir',
        (t) async {
      await _pump(t);

      expect(find.text('Henüz finans hareketi eklenmedi.'), findsOneWidget);
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();
      expect(find.text('Yeni Finans Hareketi'), findsOneWidget);
    });

    testWidgets('kayıtları tarih azalan sıralar ve toplamı gösterir',
        (t) async {
      await _pump(t, transactions: _sample());

      expect(find.text('Eylül kirası'), findsOneWidget);
      expect(find.text('1.250,50 TL'), findsOneWidget);
      expect(find.text('500,00 TL'), findsOneWidget);
      expect(find.text('2 kayıt'), findsOneWidget);
      expect(find.text('Toplam: 1.750,50 TL'), findsOneWidget);

      expect(
        t.getTopLeft(find.text('KDV')).dy <
            t.getTopLeft(find.text('Eylül kirası')).dy,
        isTrue,
      );
    });

    testWidgets('yeni hareket düğmesi sağ üst köşede bulunur', (t) async {
      await _pump(t, transactions: _sample());

      final rect = t.getRect(find.byKey(const Key('new-transaction-fab')));
      expect(rect.right, greaterThan(1200));
      expect(rect.top, lessThan(100));
    });

    testWidgets('cari filtresi listeyi ve toplamı süzer, temizlenebilir',
        (t) async {
      await _pump(t, transactions: _sample());

      await _pickCustomer(t, const Key('filter-customer'), 'Zeynep Kaya');
      expect(find.text('KDV'), findsOneWidget);
      expect(find.text('Eylül kirası'), findsNothing);
      expect(find.text('Toplam: 500,00 TL'), findsOneWidget);

      await t.tap(find.text('Filtreleri Temizle'));
      await t.pumpAndSettle();
      expect(find.text('Eylül kirası'), findsOneWidget);
      expect(find.text('Toplam: 1.750,50 TL'), findsOneWidget);
    });

    testWidgets('işlem tipi filtresi çalışır', (t) async {
      await _pump(t, transactions: _sample());

      await _pickType(t, find.byType(DropdownButtonFormField<int?>), 'Vergi');

      expect(find.text('KDV'), findsOneWidget);
      expect(find.text('Eylül kirası'), findsNothing);
      expect(find.text('Toplam: 500,00 TL'), findsOneWidget);
    });

    testWidgets('eşleşme yoksa filtre mesajı gösterir', (t) async {
      await _pump(t, transactions: _sample());

      await _pickCustomer(t, const Key('filter-customer'), 'Ahmet Yılmaz');
      await _pickType(t, find.byType(DropdownButtonFormField<int?>), 'Vergi');

      expect(
        find.text('Seçilen filtrelere uygun kayıt bulunamadı.'),
        findsOneWidget,
      );
    });

    testWidgets('silme onay ister ve kaydı kaldırır', (t) async {
      final repo = await _pump(t, transactions: _sample());

      await t.tap(find.byTooltip('Sil').first); // en yeni: KDV
      await t.pumpAndSettle();
      expect(find.text('Finans hareketi silinsin mi?'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Sil'));
      await t.pumpAndSettle();

      expect(repo.transactions.map((x) => x.id), [1]);
      expect(find.text('KDV'), findsNothing);
      expect(find.text('Finans hareketi silindi.'), findsOneWidget);
      expect(find.text('Toplam: 1.250,50 TL'), findsOneWidget);
    });

    testWidgets('silmekten vazgeçilirse kayıt korunur', (t) async {
      final repo = await _pump(t, transactions: _sample());

      await t.tap(find.byTooltip('Sil').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();

      expect(repo.transactions, hasLength(2));
      expect(find.text('KDV'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('zorunlu alanlar boşken kaydedilemez', (t) async {
      final repo = await _pump(t, transactions: _sample());
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(find.text('Cari seçiniz.'), findsOneWidget);
      expect(find.text('İşlem tipi seçiniz.'), findsOneWidget);
      expect(find.text('Tutar giriniz.'), findsOneWidget);
      expect(repo.transactions, hasLength(2));
    });

    testWidgets('geçersiz ve sıfır tutar reddedilir', (t) async {
      await _pump(t, transactions: _sample());
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('field-amount')), '12.5');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(find.textContaining('Geçerli bir tutar'), findsOneWidget);

      await t.enterText(find.byKey(const Key('field-amount')), '0');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(find.textContaining("0'dan büyük"), findsOneWidget);
    });

    testWidgets('yeni hareket kuruşa çevrilerek kaydedilir', (t) async {
      final repo = await _pump(t);
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await _pickCustomer(t, const Key('field-customer'), 'Ahmet Yılmaz');
      await _pickType(t, find.byKey(const Key('field-type')), 'Kira');
      await t.enterText(find.byKey(const Key('field-amount')), '1.250,50');
      await t.enterText(find.byKey(const Key('field-note')), ' Test notu ');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      final saved = repo.transactions.single;
      expect(saved.customerId, 1);
      expect(saved.transactionTypeId, 1);
      expect(saved.amountKurus, 125050);
      expect(saved.note, 'Test notu');
      expect(saved.transactionDate, AppDate.today());

      expect(find.text('Finans hareketi kaydedildi.'), findsOneWidget);
      expect(find.text('Test notu'), findsOneWidget);
    });

    testWidgets('tarih seçici ile tarih değiştirilebilir', (t) async {
      await _pump(t, transactions: _sample());
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('field-date')));
      await t.pumpAndSettle();
      await t.tap(find.text('15'));
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();

      final today = AppDate.today();
      final expected =
          AppDate.formatDisplay(DateTime(today.year, today.month, 15));
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('field-date')))
            .controller!
            .text,
        expected,
      );
    });

    testWidgets('yeni kayıtta yalnızca aktif cari ve tipler seçilebilir',
        (t) async {
      await _pump(
        t,
        customers: [
          makeCustomer(),
          makeCustomer(
              id: 2, firstName: 'Pasif', lastName: 'Firma', isActive: false),
        ],
        types: [makeType(), makeType(id: 2, name: 'Eski Tip', isActive: false)],
      );
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('field-customer')));
      await t.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Ahmet Yılmaz')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Pasif Firma')),
        findsNothing,
      );
      await t.tap(
        find.descendant(of: dialog, matching: find.text('Vazgeç')),
      );
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('field-type')));
      await t.pumpAndSettle();
      expect(find.text('Kira'), findsWidgets);
      expect(find.text('Eski Tip'), findsNothing);
    });

    testWidgets('cari seçicide arama Türkçe duyarsız çalışır', (t) async {
      await _pump(
        t,
        customers: [
          makeCustomer(firstName: 'İlker', lastName: 'Şahin'),
          makeCustomer(id: 2, firstName: 'Zeynep', lastName: 'Kaya'),
        ],
      );
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('field-customer')));
      await t.pumpAndSettle();

      await t.enterText(
        find.byKey(const Key('customer-picker-search')),
        'sahin',
      );
      await t.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('İlker Şahin')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Zeynep Kaya')),
        findsNothing,
      );
    });

    testWidgets('düzenleme mevcut değerlerle açılır ve günceller', (t) async {
      final repo = await _pump(t, transactions: [_sample().first]);

      await t.tap(find.byTooltip('Düzenle'));
      await t.pumpAndSettle();

      expect(find.text('Finans Hareketi Düzenle'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('field-customer')),
          matching: find.text('Ahmet Yılmaz'),
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('field-amount')))
            .controller!
            .text,
        '1.250,50',
      );
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('field-note')))
            .controller!
            .text,
        'Eylül kirası',
      );

      await t.enterText(find.byKey(const Key('field-amount')), '2.000');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(repo.transactions.single.amountKurus, 200000);
      expect(repo.transactions.single.note, 'Eylül kirası');
      expect(find.text('2.000,00 TL'), findsWidgets);
    });

    testWidgets('Esc ile vazgeçilir ve liste ekranına dönülür', (t) async {
      await _pump(t, transactions: _sample());
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('field-amount')));
      await t.pumpAndSettle();

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();

      expect(find.text('Yeni Finans Hareketi'), findsNothing);
      expect(find.text('Yeni Hareket Ekle'), findsOneWidget);
    });

    testWidgets('Ctrl+Enter ile kaydedilir', (t) async {
      final repo = await _pump(t);
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await _pickCustomer(t, const Key('field-customer'), 'Ahmet Yılmaz');
      await _pickType(t, find.byKey(const Key('field-type')), 'Kira');
      await t.enterText(find.byKey(const Key('field-amount')), '300');

      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();

      expect(repo.transactions.single.amountKurus, 30000);
    });

    testWidgets('cari seçicide Enter ilk eşleşmeyi seçer', (t) async {
      await _pump(
        t,
        customers: [
          makeCustomer(firstName: 'İlker', lastName: 'Şahin'),
          makeCustomer(id: 2, firstName: 'Zeynep', lastName: 'Kaya'),
        ],
      );
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('field-customer')));
      await t.pumpAndSettle();

      await t.enterText(
          find.byKey(const Key('customer-picker-search')), 'kaya');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('field-customer')),
          matching: find.text('Zeynep Kaya'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('en küçük pencerede cari seçici diyaloğu taşmaz', (t) async {
      await _pump(t, size: const Size(900, 600));
      await t.tap(find.byKey(const Key('new-transaction-fab')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('field-customer')));
      await t.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('pasif tipli eski hareket düzenlenirken tip seçili kalır',
        (t) async {
      final repo = await _pump(
        t,
        types: [makeType(isActive: false)],
        transactions: [_sample().first],
      );

      await t.tap(find.byTooltip('Düzenle'));
      await t.pumpAndSettle();

      expect(find.text('Kira (Pasif)'), findsWidgets);

      await t.enterText(find.byKey(const Key('field-amount')), '300');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(repo.transactions.single.amountKurus, 30000);
      expect(repo.transactions.single.transactionTypeId, 1);
    });
  });
}
