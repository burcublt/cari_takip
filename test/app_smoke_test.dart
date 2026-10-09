import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_dashboard_repository.dart';
import 'helpers/fake_transaction_type_repository.dart';

Widget _app() => ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository()),
        customerRepositoryProvider
            .overrideWithValue(FakeCustomerRepository()),
        transactionTypeRepositoryProvider
            .overrideWithValue(FakeTransactionTypeRepository()),
      ],
      child: const CariTakipApp(),
    );

void main() {
  testWidgets('uygulama Dashboard ile açılır', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Aktif Cari'), findsOneWidget);
    expect(find.text('Son Hareketler'), findsOneWidget);
  });

  testWidgets('sidebar ile Raporlar ekranına geçilir', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Raporlar'));
    await tester.pumpAndSettle();

    expect(find.text('Raporla'), findsOneWidget);
  });
}
