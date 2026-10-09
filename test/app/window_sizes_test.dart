import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/reports/presentation/report_providers.dart';
import 'package:cari_takip/features/settings/presentation/settings_providers.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cari_takip/core/backup/backup_models.dart';
import '../helpers/fake_backup_services.dart';
import '../helpers/fake_customer_repository.dart';
import '../helpers/fake_dashboard_repository.dart';
import '../helpers/fake_report_repository.dart';
import '../helpers/fake_transaction_repository.dart';
import '../helpers/fake_transaction_type_repository.dart';

Future<void> _pumpApp(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final customerRepo = FakeCustomerRepository([
    makeCustomer(),
    makeCustomer(
      id: 2,
      firstName: 'Çok Uzun Unvanlı Ticaret Anonim Şirketi',
      lastName: 'Yönetim Kurulu',
      phone: '0532 111 22 33',
    ),
    makeCustomer(id: 3, firstName: 'Pasif', lastName: 'Firma', isActive: false),
  ]);
  final typeRepo = FakeTransactionTypeRepository([
    makeType(),
    makeType(id: 2, name: 'Muhasebe Ücreti'),
  ]);
  final transactionRepo = FakeTransactionRepository(
    customers: customerRepo,
    types: typeRepo,
    initial: [
      makeTransaction(note: 'Eylül kirası ve ortak gider payı ödemesi'),
      makeTransaction(
        id: 2,
        customerId: 2,
        customerName: 'Çok Uzun Unvanlı Ticaret Anonim Şirketi Yönetim Kurulu',
        transactionTypeId: 2,
        transactionTypeName: 'Muhasebe Ücreti',
        amountKurus: 999999999,
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          FakeDashboardRepository(
            makeSummary(
              activeCustomerCount: 12,
              transactionCount: 1234,
              totalAmountKurus: 123456789012,
              monthAmountKurus: 98765432,
              monthTransactionCount: 87,
              recent: [
                makeRecent(
                  customerName: 'Çok Uzun Unvanlı Ticaret Anonim Şirketi',
                  amountKurus: 999999999,
                ),
                makeRecent(id: 2),
              ],
            ),
          ),
        ),
        customerRepositoryProvider.overrideWithValue(customerRepo),
        transactionTypeRepositoryProvider.overrideWithValue(typeRepo),
        transactionRepositoryProvider.overrideWithValue(transactionRepo),
        reportRepositoryProvider
            .overrideWithValue(FakeReportRepository(transactionRepo)),
        backupServiceProvider.overrideWithValue(
          FakeBackupService([
            makeBackup(),
            makeBackup(
              name: 'cari_takip_manual_2026-09-20_101500.db',
              kind: BackupKind.manual,
            ),
          ]),
        ),
        restoreServiceProvider.overrideWithValue(FakeRestoreService()),
        backupFileChooserProvider.overrideWithValue(FakeBackupFileChooser()),
        integrityCheckerProvider.overrideWithValue(() async => true),
        systemInfoProvider.overrideWith(
          (ref) async => const SystemInfo(
            dataDirectory:
                '/Users/kullanici/Library/Application Support/CariTakip',
            databasePath:
                '/Users/kullanici/Library/Application Support/CariTakip/cari_takip.db',
            backupDirectory:
                '/Users/kullanici/Library/Application Support/CariTakip/backups',
            schemaVersion: 1,
            databaseSizeBytes: 5242880,
          ),
        ),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tüm ekranları ve başlıca formları dolaşır; her adımda taşma/istisna olmamalı.
/// Pencere minimum boyutun altındaysa içerik kaydırıldığı için öğeler önce
/// görünür alana getirilir.
Future<void> _visitEverything(WidgetTester t) async {
  Future<void> tapVisible(Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  Future<void> go(String railLabel, String expectedText) async {
    await tapVisible(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byTooltip(railLabel),
      ),
    );
    expect(find.text(expectedText), findsWidgets, reason: railLabel);
    expect(t.takeException(), isNull, reason: railLabel);
  }

  expect(find.text('Aktif Cari'), findsOneWidget);
  expect(t.takeException(), isNull, reason: 'Dashboard');

  await go('Cariler', 'Yeni Cari');
  await tapVisible(find.text('Yeni Cari'));
  expect(find.byKey(const Key('field-firstName')), findsOneWidget);
  expect(t.takeException(), isNull, reason: 'Cari formu');

  await go('Finans Hareketleri', 'Yeni Hareket');
  await tapVisible(find.text('Yeni Hareket'));
  expect(find.byKey(const Key('field-amount')), findsOneWidget);
  expect(t.takeException(), isNull, reason: 'Hareket formu');

  await go('İşlem Tipleri', 'Yeni İşlem Tipi');
  await go('Raporlar', 'Raporla');

  await tapVisible(find.byKey(const Key('nav-settings')));
  expect(find.text('Yedekleme'), findsOneWidget);
  expect(t.takeException(), isNull, reason: 'Ayarlar');
}

void main() {
  for (final size in const [
    Size(900, 600),
    Size(1024, 700),
    Size(1366, 768),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'tüm ekranlar ${size.width.toInt()}x${size.height.toInt()} pencerede '
      'bozulmaz',
      (t) async {
        await _pumpApp(t, size, 1);
        await _visitEverything(t);
      },
    );
  }

  testWidgets('tüm ekranlar 1,3x yazı büyütmede bozulmaz', (t) async {
    await _pumpApp(t, const Size(1400, 900), 1.3);
    await _visitEverything(t);
  });

  testWidgets('tüm ekranlar en küçük pencere ve 1,3x yazıda bozulmaz',
      (t) async {
    await _pumpApp(t, const Size(900, 600), 1.3);
    await _visitEverything(t);
  });

  testWidgets('minimum altındaki pencerede de taşma istisnası oluşmaz',
      (t) async {
    await _pumpApp(t, const Size(640, 420), 1);
    await _visitEverything(t);
  });
}
