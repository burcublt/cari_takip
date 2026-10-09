import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/core/widgets/min_size_scroller.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_backup_services.dart';
import '../helpers/fake_customer_repository.dart';
import '../helpers/fake_dashboard_repository.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository()),
        customerRepositoryProvider
            .overrideWithValue(FakeCustomerRepository([makeCustomer()])),
        backupServiceProvider.overrideWithValue(FakeBackupService()),
        restoreServiceProvider.overrideWithValue(FakeRestoreService()),
        backupFileChooserProvider.overrideWithValue(FakeBackupFileChooser()),
        integrityCheckerProvider.overrideWithValue(() async => true),
        systemInfoProvider.overrideWith(
          (ref) async => const SystemInfo(
            dataDirectory: '/veri',
            databasePath: '/veri/cari_takip.db',
            backupDirectory: '/veri/backups',
            schemaVersion: 1,
            databaseSizeBytes: 1024,
          ),
        ),
      ],
      child: const CariTakipApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _railItem(String label) => find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    );

int? _selectedIndex(WidgetTester t) =>
    t.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

void main() {
  group('geniş pencere', () {
    testWidgets('menü açık gelir: başlık, etiketler ve alttaki Ayarlar',
        (t) async {
      await _pump(t, const Size(1400, 900));

      expect(find.text('Cari Takip'), findsOneWidget);
      for (final label in [
        'Dashboard',
        'Cariler',
        'Finans Hareketleri',
        'İşlem Tipleri',
        'Raporlar',
      ]) {
        expect(_railItem(label), findsOneWidget, reason: label);
      }

      // Ayarlar, ana menü öğelerinin altında ayrı durur.
      final settings = t.getTopLeft(find.byKey(const Key('nav-settings'))).dy;
      expect(settings, greaterThan(t.getTopLeft(_railItem('Raporlar')).dy));
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Ayarlar'),
        ),
        findsNothing,
      );
    });

    testWidgets('daralt düğmesi menüyü kompakt yapar, genişlet geri açar',
        (t) async {
      await _pump(t, const Size(1400, 900));

      await t.tap(find.byTooltip('Menüyü daralt'));
      await t.pumpAndSettle();

      expect(find.text('Cari Takip'), findsNothing);
      expect(find.byTooltip('Menüyü genişlet'), findsOneWidget);
      // Kompakt menüde etiketler ikonların altında görünmeye devam eder.
      expect(_railItem('Cariler'), findsOneWidget);
      expect(t.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          isFalse);

      await t.tap(find.byTooltip('Menüyü genişlet'));
      await t.pumpAndSettle();

      expect(find.text('Cari Takip'), findsOneWidget);
      expect(t.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          isTrue);
    });

    testWidgets('kompakt tercih sayfalar arası geçişte korunur', (t) async {
      await _pump(t, const Size(1400, 900));
      await t.tap(find.byTooltip('Menüyü daralt'));
      await t.pumpAndSettle();

      await t.tap(_railItem('Cariler'));
      await t.pumpAndSettle();

      expect(find.text('Cari Takip'), findsNothing);
      expect(find.byTooltip('Menüyü genişlet'), findsOneWidget);
    });
  });

  group('dar pencere', () {
    testWidgets('menü otomatik kompakt olur ve daralt düğmesi görünmez',
        (t) async {
      await _pump(t, const Size(950, 700));

      expect(find.text('Cari Takip'), findsNothing);
      expect(find.byTooltip('Menüyü daralt'), findsNothing);
      expect(find.byTooltip('Menüyü genişlet'), findsNothing);
      expect(_railItem('Dashboard'), findsOneWidget);
      expect(find.byKey(const Key('nav-settings')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('pencere büyüyünce menü kendiliğinden açılır', (t) async {
      await _pump(t, const Size(950, 700));

      t.view.physicalSize = const Size(1400, 900);
      await t.pumpAndSettle();

      expect(find.text('Cari Takip'), findsOneWidget);
    });
  });

  group('çok küçük pencere', () {
    testWidgets('içerik kaydırılabilir kalır, taşma olmaz', (t) async {
      await _pump(t, const Size(700, 450));

      expect(t.takeException(), isNull);
      expect(find.byType(MinSizeScroller), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MinSizeScroller),
          matching: find.byType(SingleChildScrollView),
        ),
        findsWidgets,
      );
      expect(
        t.widget<NavigationRail>(find.byType(NavigationRail)).labelType,
        NavigationRailLabelType.none,
      );
      expect(find.byTooltip('Dashboard'), findsOneWidget);
      expect(find.text('Aktif Cari'), findsOneWidget);
    });

    testWidgets('minimum boyutta (900x600) kaydırıcı gerekmez', (t) async {
      await _pump(t, const Size(900, 600));

      expect(
        find.descendant(
          of: find.byType(MinSizeScroller),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('gezinme', () {
    testWidgets('menü geçişinde önceki sayfa ekranda kalmaz', (t) async {
      await _pump(t, const Size(1400, 900));

      await t.tap(_railItem('Cariler'));
      await t.pump();

      expect(find.text('Yeni Cari'), findsOneWidget);
      expect(find.text('Aktif Cari'), findsNothing);
    });

    testWidgets('seçili öğe rotayı izler; Ayarlar seçilince menüde seçili yok',
        (t) async {
      await _pump(t, const Size(1400, 900));
      expect(_selectedIndex(t), 0);

      await t.tap(_railItem('Cariler'));
      await t.pumpAndSettle();
      expect(_selectedIndex(t), 1);

      await t.tap(find.byKey(const Key('nav-settings')));
      await t.pumpAndSettle();
      expect(_selectedIndex(t), isNull);
      expect(find.text('Sistem Bilgileri'), findsOneWidget);

      await t.tap(_railItem('Dashboard'));
      await t.pumpAndSettle();
      expect(_selectedIndex(t), 0);
      expect(find.text('Aktif Cari'), findsOneWidget);
    });

    testWidgets('cari alt sayfalarında Cariler seçili kalır', (t) async {
      await _pump(t, const Size(1400, 900));

      await t.tap(_railItem('Cariler'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Detay'));
      await t.pumpAndSettle();

      expect(_selectedIndex(t), 1);
    });
  });
}
