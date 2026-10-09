import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_summary.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_customer_repository.dart';
import '../../../helpers/fake_dashboard_repository.dart';
import '../../../helpers/fake_transaction_repository.dart';
import '../../../helpers/fake_transaction_type_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  DashboardSummary summary, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final customerRepo = FakeCustomerRepository([makeCustomer()]);
  final typeRepo = FakeTransactionTypeRepository([makeType()]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository(summary)),
        customerRepositoryProvider.overrideWithValue(customerRepo),
        transactionTypeRepositoryProvider.overrideWithValue(typeRepo),
        transactionRepositoryProvider.overrideWithValue(
          FakeTransactionRepository(customers: customerRepo, types: typeRepo),
        ),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();
}

DashboardSummary _filled() => makeSummary(
      activeCustomerCount: 7,
      transactionCount: 42,
      totalAmountKurus: 1234567,
      monthAmountKurus: 250075,
      monthTransactionCount: 3,
      recent: [
        makeRecent(),
        makeRecent(
          id: 2,
          date: DateTime(2026, 9, 10),
          customerName: 'Zeynep Kaya',
          typeName: 'Vergi',
          amountKurus: 50000,
        ),
      ],
    );

void main() {
  testWidgets('özet kartlarını doğru değerlerle gösterir', (t) async {
    await _pump(t, _filled());

    expect(find.text('Aktif Cari'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Toplam Hareket'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Genel Kayıtlı Tutar'), findsOneWidget);
    expect(find.text('12.345,67 TL'), findsOneWidget);
    expect(find.text('Bu Ay Toplamı'), findsOneWidget);
    expect(find.text('2.500,75 TL'), findsOneWidget);
    expect(find.text('Eylül 2026 · 3 hareket'), findsOneWidget);
  });

  testWidgets('son hareketleri tarih, cari, tip ve tutarla listeler',
      (t) async {
    await _pump(t, _filled());

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('15.09.2026'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('1.250,50 TL'), findsOneWidget);
    expect(find.text('500,00 TL'), findsOneWidget);
  });

  testWidgets('Tümünü Gör finans hareketleri listesine gider', (t) async {
    await _pump(t, _filled());

    await t.tap(find.text('Tümünü Gör'));
    await t.pumpAndSettle();

    expect(find.text('Yeni Hareket'), findsOneWidget);
  });

  testWidgets('hiç cari yokken cari ekleme yönlendirmesi gösterir', (t) async {
    await _pump(t, makeSummary());

    expect(find.text('Başlamak için bir cari ekleyin.'), findsOneWidget);
    expect(find.text('Tümünü Gör'), findsNothing);
    expect(find.text('0,00 TL'), findsWidgets);

    await t.tap(find.text('Yeni Cari Ekle'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('field-firstName')), findsOneWidget);
  });

  testWidgets('cari var ama hareket yoksa hareket ekleme yönlendirmesi gösterir',
      (t) async {
    await _pump(t, makeSummary(activeCustomerCount: 2));

    expect(find.text('Henüz finans hareketi eklenmedi.'), findsOneWidget);

    await t.tap(find.text('Yeni Hareket Ekle'));
    await t.pumpAndSettle();
    expect(find.text('Yeni Finans Hareketi'), findsOneWidget);
  });

  testWidgets('dar pencerede taşma olmadan çalışır', (t) async {
    await _pump(t, _filled(), size: const Size(800, 600));

    expect(t.takeException(), isNull);
    expect(find.text('Genel Kayıtlı Tutar'), findsOneWidget);
    expect(find.text('Son Hareketler'), findsOneWidget);
  });

  testWidgets('geniş pencerede dört kart tek satırda durur', (t) async {
    await _pump(t, _filled());

    final first = t.getTopLeft(find.text('Aktif Cari')).dy;
    final last = t.getTopLeft(find.text('Bu Ay Toplamı')).dy;
    expect(last, first);
  });
}
