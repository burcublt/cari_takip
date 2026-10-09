import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
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

/// Uygulamayı masaüstü boyutunda açar ve Cariler sayfasına gider.
Future<FakeCustomerRepository> _pumpCustomers(
  WidgetTester tester, {
  List<Customer>? customers,
  CustomerSummary? summary,
  List<FinancialTransaction>? transactions,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeCustomerRepository(customers);
  if (summary != null) repo.summary = summary;
  final typeRepo = FakeTransactionTypeRepository([makeType()]);
  final transactionRepo = FakeTransactionRepository(
    customers: repo,
    types: typeRepo,
    initial: transactions,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository()),
        customerRepositoryProvider.overrideWithValue(repo),
        transactionTypeRepositoryProvider.overrideWithValue(typeRepo),
        transactionRepositoryProvider.overrideWithValue(transactionRepo),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Cariler'),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tapSegment(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<CustomerStatusFilter>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

void main() {
  group('liste', () {
    testWidgets('cari yoksa empty state ve yönlendirme gösterir', (t) async {
      await _pumpCustomers(t);

      expect(find.text('Henüz cari eklenmedi.'), findsOneWidget);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();

      expect(find.text('Yeni Cari'), findsOneWidget);
      expect(find.byKey(const Key('field-firstName')), findsOneWidget);
    });

    testWidgets('varsayılan olarak yalnızca aktif carileri listeler',
        (t) async {
      await _pumpCustomers(
        t,
        customers: [
          makeCustomer(),
          makeCustomer(
            id: 2,
            firstName: 'Pasif',
            lastName: 'Firma',
            isActive: false,
          ),
        ],
      );

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('0532 111 22 33'), findsOneWidget);
      expect(find.text('1234567890'), findsOneWidget);
      expect(find.text('Pasif Firma'), findsNothing);

      await _tapSegment(t, 'Pasif');
      expect(find.text('Pasif Firma'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsNothing);

      await _tapSegment(t, 'Tümü');
      expect(find.text('Pasif Firma'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    });

    testWidgets('arama listeyi süzer ve sonuç yoksa mesaj gösterir',
        (t) async {
      await _pumpCustomers(
        t,
        customers: [
          makeCustomer(),
          makeCustomer(id: 2, firstName: 'Zeynep', lastName: 'Kaya'),
        ],
      );

      await t.enterText(find.byKey(const Key('customer-search')), 'kaya');
      await t.pumpAndSettle();
      expect(find.text('Zeynep Kaya'), findsOneWidget);
      expect(find.text('Ahmet Yılmaz'), findsNothing);

      await t.enterText(find.byKey(const Key('customer-search')), 'yokyok');
      await t.pumpAndSettle();
      expect(find.text('Aramanıza uygun cari bulunamadı.'), findsOneWidget);
    });

    testWidgets('pasife alma onay ister ve cariyi aktif listeden çıkarır',
        (t) async {
      final repo = await _pumpCustomers(t, customers: [makeCustomer()]);

      await t.tap(find.byTooltip('Pasife Al'));
      await t.pumpAndSettle();
      expect(find.text('Cari pasife alınsın mı?'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Pasife Al'));
      await t.pumpAndSettle();

      expect(repo.customers.single.isActive, isFalse);
      expect(find.text('Ahmet Yılmaz'), findsNothing);
      expect(find.text('Cari pasife alındı.'), findsOneWidget);
    });

    testWidgets('pasife almaktan vazgeçilirse cari aktif kalır', (t) async {
      final repo = await _pumpCustomers(t, customers: [makeCustomer()]);

      await t.tap(find.byTooltip('Pasife Al'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();

      expect(repo.customers.single.isActive, isTrue);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    });

    testWidgets('pasif cari onaysız tekrar aktif edilir', (t) async {
      final repo = await _pumpCustomers(
        t,
        customers: [makeCustomer(isActive: false)],
      );
      await _tapSegment(t, 'Pasif');

      await t.tap(find.byTooltip('Aktif Et'));
      await t.pumpAndSettle();

      expect(repo.customers.single.isActive, isTrue);
      expect(find.text('Cari aktif edildi.'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('boş ad ile kaydedilemez', (t) async {
      final repo = await _pumpCustomers(t);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();

      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(find.text('Ad / Unvan zorunludur.'), findsOneWidget);
      expect(repo.customers, isEmpty);
    });

    testWidgets('yeni cari trim edilerek kaydedilir ve detaya gidilir',
        (t) async {
      final repo = await _pumpCustomers(t);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();

      await t.enterText(
        find.byKey(const Key('field-firstName')),
        '  Yeni Firma  ',
      );
      await t.enterText(find.byKey(const Key('field-phone')), ' 0555 ');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      final saved = repo.customers.single;
      expect(saved.firstName, 'Yeni Firma');
      expect(saved.phone, '0555');
      expect(saved.lastName, isNull);
      expect(saved.taxNumber, isNull);

      expect(find.text('Cari kaydedildi.'), findsOneWidget);
      expect(find.text('Hareket Özeti'), findsOneWidget);
      expect(find.text('Yeni Firma'), findsWidgets);
    });

    testWidgets('yeni formda ilk alan otomatik odaklanır', (t) async {
      await _pumpCustomers(t);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();

      final editable = t.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('field-firstName')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
    });

    testWidgets('Esc ile vazgeçilir ve liste ekranına dönülür', (t) async {
      final repo = await _pumpCustomers(t);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('field-firstName')), 'Yarım');

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();

      expect(repo.customers, isEmpty);
      expect(find.byKey(const Key('field-firstName')), findsNothing);
      expect(find.text('Henüz cari eklenmedi.'), findsOneWidget);
    });

    testWidgets('Ctrl+Enter ile kaydedilir', (t) async {
      final repo = await _pumpCustomers(t);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('field-firstName')), 'Kısayol');

      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();

      expect(repo.customers.single.firstName, 'Kısayol');
    });

    testWidgets('kaydetme sırasında kısayol ikinci kez kayıt oluşturmaz',
        (t) async {
      final repo = await _pumpCustomers(t);
      await t.tap(find.text('Yeni Cari Ekle'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('field-firstName')), 'Tek');

      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();

      expect(repo.customers, hasLength(1));
    });

    testWidgets('düzenleme mevcut değerlerle açılır ve günceller', (t) async {
      final repo = await _pumpCustomers(t, customers: [makeCustomer()]);

      await t.tap(find.byTooltip('Düzenle'));
      await t.pumpAndSettle();

      expect(find.text('Cari Düzenle'), findsOneWidget);
      expect(_fieldText(t, 'field-firstName'), 'Ahmet');
      expect(_fieldText(t, 'field-lastName'), 'Yılmaz');
      expect(_fieldText(t, 'field-phone'), '0532 111 22 33');

      await t.enterText(find.byKey(const Key('field-firstName')), 'Mehmet');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      expect(repo.customers.single.firstName, 'Mehmet');
      expect(repo.customers.single.lastName, 'Yılmaz');
      expect(find.text('Mehmet Yılmaz'), findsOneWidget);
    });
  });

  group('detay', () {
    testWidgets('bilgileri, özeti ve aksiyonları gösterir', (t) async {
      await _pumpCustomers(
        t,
        customers: [makeCustomer()],
        summary: const CustomerSummary(transactionCount: 3, totalKurus: 125050),
      );

      await t.tap(find.byTooltip('Detay'));
      await t.pumpAndSettle();

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('0532 111 22 33'), findsOneWidget);
      expect(find.text('1.250,50 TL'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Tüm Hareketleri Gör'), findsOneWidget);
      expect(_outlined(t, 'Yeni Hareket Ekle').onPressed, isNotNull);
    });

    testWidgets('son finans hareketlerini listeler', (t) async {
      await _pumpCustomers(
        t,
        customers: [makeCustomer()],
        transactions: [
          makeTransaction(note: 'Eylül kirası'),
          makeTransaction(id: 2, amountKurus: 50000, note: 'Ek ödeme'),
        ],
      );
      await t.tap(find.byTooltip('Detay'));
      await t.pumpAndSettle();

      expect(find.text('Son Finans Hareketleri'), findsOneWidget);
      expect(find.text('Eylül kirası'), findsOneWidget);
      expect(find.text('Ek ödeme'), findsOneWidget);
      expect(find.text('1.250,50 TL'), findsOneWidget);
    });

    testWidgets('hareketi olmayan cari için boş mesaj gösterir', (t) async {
      await _pumpCustomers(t, customers: [makeCustomer()]);
      await t.tap(find.byTooltip('Detay'));
      await t.pumpAndSettle();

      expect(
        find.text('Bu cariye ait finans hareketi bulunmuyor.'),
        findsOneWidget,
      );
    });

    testWidgets('Tüm Hareketleri Gör cariye göre süzülmüş listeyi açar',
        (t) async {
      await _pumpCustomers(
        t,
        customers: [
          makeCustomer(),
          makeCustomer(id: 2, firstName: 'Zeynep', lastName: 'Kaya'),
        ],
        transactions: [
          makeTransaction(note: 'Ahmet notu'),
          makeTransaction(
            id: 2,
            customerId: 2,
            customerName: 'Zeynep Kaya',
            note: 'Zeynep notu',
          ),
        ],
      );
      await t.tap(find.byTooltip('Detay').first);
      await t.pumpAndSettle();

      await t.tap(find.text('Tüm Hareketleri Gör'));
      await t.pumpAndSettle();

      expect(find.text('Ahmet notu'), findsOneWidget);
      expect(find.text('Zeynep notu'), findsNothing);
      expect(find.text('Filtreleri Temizle'), findsOneWidget);
    });

    testWidgets('Yeni Hareket Ekle cariyi önceden seçili açar', (t) async {
      await _pumpCustomers(t, customers: [makeCustomer()]);
      await t.tap(find.byTooltip('Detay'));
      await t.pumpAndSettle();

      await t.tap(find.text('Yeni Hareket Ekle'));
      await t.pumpAndSettle();

      expect(find.text('Yeni Finans Hareketi'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('field-customer')),
          matching: find.text('Ahmet Yılmaz'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pasife alınca durum güncellenir, yeni hareket kapanır',
        (t) async {
      await _pumpCustomers(t, customers: [makeCustomer()]);
      await t.tap(find.byTooltip('Detay'));
      await t.pumpAndSettle();

      await t.tap(find.widgetWithText(OutlinedButton, 'Pasife Al'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Pasife Al'));
      await t.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Aktif Et'), findsOneWidget);
      expect(_outlined(t, 'Yeni Hareket Ekle').onPressed, isNull);
    });
  });
}

OutlinedButton _outlined(WidgetTester t, String label) =>
    t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));
