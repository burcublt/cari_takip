import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/reports/presentation/report_providers.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_customer_repository.dart';
import '../../../helpers/fake_dashboard_repository.dart';
import '../../../helpers/fake_report_repository.dart';
import '../../../helpers/fake_transaction_repository.dart';
import '../../../helpers/fake_transaction_type_repository.dart';

Future<void> _pump(
  WidgetTester tester, {
  List<FinancialTransaction>? transactions,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final customerRepo = FakeCustomerRepository([
    makeCustomer(),
    makeCustomer(id: 2, firstName: 'Zeynep', lastName: 'Kaya'),
  ]);
  final typeRepo = FakeTransactionTypeRepository([
    makeType(),
    makeType(id: 2, name: 'Vergi'),
  ]);
  final transactionRepo = FakeTransactionRepository(
    customers: customerRepo,
    types: typeRepo,
    initial: transactions ?? _sample(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository()),
        customerRepositoryProvider.overrideWithValue(customerRepo),
        transactionTypeRepositoryProvider.overrideWithValue(typeRepo),
        transactionRepositoryProvider.overrideWithValue(transactionRepo),
        reportRepositoryProvider
            .overrideWithValue(FakeReportRepository(transactionRepo)),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Raporlar'),
    ),
  );
  await tester.pumpAndSettle();
}

List<FinancialTransaction> _sample() => [
      makeTransaction(date: DateTime(2026, 9), amountKurus: 100000, note: 'a'),
      makeTransaction(
        id: 2,
        date: DateTime(2026, 9, 15),
        amountKurus: 50000,
        note: 'b',
      ),
      makeTransaction(
        id: 3,
        transactionTypeId: 2,
        transactionTypeName: 'Vergi',
        date: DateTime(2026, 9, 20),
        amountKurus: 25025,
        note: 'c',
      ),
      makeTransaction(
        id: 4,
        customerId: 2,
        customerName: 'Zeynep Kaya',
        date: DateTime(2026, 9, 15),
        amountKurus: 999900,
        note: 'zeynep',
      ),
    ];

Future<void> _selectCustomer(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('report-customer')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(name)),
  );
  await tester.pumpAndSettle();
}

Future<void> _run(WidgetTester tester) async {
  await tester.tap(find.text('Raporla'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('başlangıçta yönlendirme mesajı gösterir', (t) async {
    await _pump(t);
    expect(find.text("Rapor için cari seçip 'Raporla'ya basın."), findsOneWidget);
    expect(find.textContaining('Toplam:'), findsNothing);
  });

  testWidgets('cari seçilmeden raporlanamaz', (t) async {
    await _pump(t);

    await _run(t);

    expect(find.text('Cari seçiniz.'), findsOneWidget);
    expect(find.textContaining('Toplam:'), findsNothing);
  });

  testWidgets('cari raporu satırları, sayıyı ve toplamı gösterir', (t) async {
    await _pump(t);
    await _selectCustomer(t, 'Ahmet Yılmaz');
    await _run(t);

    expect(find.text('Ahmet Yılmaz · Tüm tarihler · Tüm tipler'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    expect(find.text('zeynep'), findsNothing);
    expect(find.text('3 kayıt'), findsOneWidget);
    expect(find.text('Toplam: 1.750,25 TL'), findsOneWidget);

    // tarih azalan: c (20 Eylül) en üstte, a (1 Eylül) en altta
    expect(t.getTopLeft(find.text('c')).dy < t.getTopLeft(find.text('b')).dy, isTrue);
    expect(t.getTopLeft(find.text('b')).dy < t.getTopLeft(find.text('a')).dy, isTrue);
  });

  testWidgets('işlem tipi filtresi sonucu ve toplamı daraltır', (t) async {
    await _pump(t);
    await _selectCustomer(t, 'Ahmet Yılmaz');

    await t.tap(find.byType(DropdownButtonFormField<int?>));
    await t.pumpAndSettle();
    await t.tap(find.text('Vergi').last);
    await t.pumpAndSettle();
    await _run(t);

    expect(find.text('c'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('1 kayıt'), findsOneWidget);
    expect(find.text('Toplam: 250,25 TL'), findsOneWidget);
    expect(find.textContaining('Vergi'), findsWidgets);
  });

  testWidgets('başlangıç tarihi filtresi sonucu süzer', (t) async {
    final today = AppDate.today();
    await _pump(
      t,
      transactions: [
        makeTransaction(
          date: DateTime(today.year, today.month, 5),
          amountKurus: 1000,
          note: 'erken',
        ),
        makeTransaction(
          id: 2,
          date: DateTime(today.year, today.month, 25),
          amountKurus: 2000,
          note: 'geç',
        ),
      ],
    );
    await _selectCustomer(t, 'Ahmet Yılmaz');

    await t.tap(find.byKey(const Key('report-from')));
    await t.pumpAndSettle();
    await t.tap(find.text('15'));
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    await _run(t);

    expect(find.text('geç'), findsOneWidget);
    expect(find.text('erken'), findsNothing);
    expect(find.text('Toplam: 20,00 TL'), findsOneWidget);
  });

  testWidgets('eşleşme yoksa mesaj ve sıfır toplam gösterir', (t) async {
    await _pump(t);
    await _selectCustomer(t, 'Zeynep Kaya');

    await t.tap(find.byType(DropdownButtonFormField<int?>));
    await t.pumpAndSettle();
    await t.tap(find.text('Vergi').last);
    await t.pumpAndSettle();
    await _run(t);

    expect(
      find.text('Seçilen filtrelere uygun kayıt bulunamadı.'),
      findsOneWidget,
    );
    expect(find.text('0 kayıt'), findsOneWidget);
    expect(find.text('Toplam: 0,00 TL'), findsOneWidget);
  });

  testWidgets('filtre değişince uyarı çıkar, tekrar Raporla ile güncellenir',
      (t) async {
    await _pump(t);
    await _selectCustomer(t, 'Ahmet Yılmaz');
    await _run(t);
    expect(find.textContaining('Filtreler değişti'), findsNothing);

    await _selectCustomer(t, 'Zeynep Kaya');
    expect(find.textContaining('Filtreler değişti'), findsOneWidget);
    expect(find.text('a'), findsOneWidget); // eski sonuç hâlâ ekranda

    await _run(t);
    expect(find.textContaining('Filtreler değişti'), findsNothing);
    expect(find.text('zeynep'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('Toplam: 9.999,00 TL'), findsOneWidget);
  });

  testWidgets('Temizle seçimleri ve sonucu sıfırlar', (t) async {
    await _pump(t);
    await _selectCustomer(t, 'Ahmet Yılmaz');
    await _run(t);
    expect(find.textContaining('Toplam:'), findsOneWidget);

    await t.tap(find.text('Temizle'));
    await t.pumpAndSettle();

    expect(find.textContaining('Toplam:'), findsNothing);
    expect(find.text("Rapor için cari seçip 'Raporla'ya basın."), findsOneWidget);
  });
}
