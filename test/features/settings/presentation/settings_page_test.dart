import 'package:cari_takip/app/app.dart';
import 'package:cari_takip/app/restart_scope.dart';
import 'package:cari_takip/core/backup/backup_models.dart';
import 'package:cari_takip/core/backup/restore_service.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:cari_takip/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_backup_services.dart';
import '../../../helpers/fake_dashboard_repository.dart';

class _Env {
  _Env({List<BackupInfo>? backups}) : backupService = FakeBackupService(backups);

  final FakeBackupService backupService;
  final FakeRestoreService restoreService = FakeRestoreService();
  final FakeBackupFileChooser chooser = FakeBackupFileChooser();
}

Future<_Env> _pump(
  WidgetTester tester, {
  List<BackupInfo>? backups,
  bool integrityOk = true,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = _Env(backups: backups);
  await tester.pumpWidget(
    AppRestartScope(
      builder: (key) => ProviderScope(
        key: key,
        overrides: [
          dashboardRepositoryProvider
              .overrideWithValue(FakeDashboardRepository()),
          backupServiceProvider.overrideWithValue(env.backupService),
          restoreServiceProvider.overrideWithValue(env.restoreService),
          backupFileChooserProvider.overrideWithValue(env.chooser),
          integrityCheckerProvider.overrideWithValue(() async => integrityOk),
          systemInfoProvider.overrideWith(
            (ref) async => const SystemInfo(
              dataDirectory: '/veri/CariTakip',
              databasePath: '/veri/CariTakip/cari_takip.db',
              backupDirectory: '/veri/CariTakip/backups',
              schemaVersion: 1,
              databaseSizeBytes: 20480,
            ),
          ),
        ],
        child: const CariTakipApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('nav-settings')));
  await tester.pumpAndSettle();
  return env;
}

Future<void> _tapRestoreConfirm(WidgetTester tester) async {
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Geri Yükle'));
  await tester.pumpAndSettle();
}

void main() {
  group('bilgi alanları', () {
    testWidgets('yedek yokken bunu belirtir', (t) async {
      await _pump(t);

      expect(find.text('Henüz yedek alınmadı.'), findsOneWidget);
      expect(find.text('Son yedekler'), findsNothing);
    });

    testWidgets('son yedeği ve yedek listesini gösterir', (t) async {
      await _pump(
        t,
        backups: [
          makeBackup(),
          makeBackup(
            name: 'cari_takip_manual_2026-09-20_101500.db',
            kind: BackupKind.manual,
            createdAt: DateTime(2026, 9, 20, 10, 15),
            sizeBytes: 1536,
          ),
        ],
      );

      expect(
        find.text('Son yedek: 29.09.2026 18:25 (Otomatik)'),
        findsOneWidget,
      );
      expect(find.text('cari_takip_2026-09-29_182500.db'), findsOneWidget);
      expect(find.text('cari_takip_manual_2026-09-20_101500.db'), findsOneWidget);
      expect(find.text('1,5 KB'), findsOneWidget);
      expect(find.text('Manuel'), findsOneWidget);
    });

    testWidgets('sistem bilgilerini gösterir', (t) async {
      await _pump(t);

      expect(find.text('/veri/CariTakip'), findsOneWidget);
      expect(find.text('/veri/CariTakip/backups'), findsOneWidget);
      expect(find.text('20,0 KB'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
    });
  });

  group('manuel yedek', () {
    testWidgets('Yedek Oluştur yedek dizinine manuel yedek alır', (t) async {
      final env = await _pump(t);

      await t.tap(find.text('Yedek Oluştur'));
      await t.pumpAndSettle();

      expect(env.backupService.created, hasLength(1));
      expect(env.backupService.created.single.kind, BackupKind.manual);
      expect(env.backupService.created.single.targetPath, isNull);
      expect(
        find.text('Yedek oluşturuldu: cari_takip_manual_2026-09-30_090000.db'),
        findsOneWidget,
      );
      expect(find.text('Son yedek: 30.09.2026 09:00 (Manuel)'), findsOneWidget);
    });

    testWidgets('Konum Seçerek Yedekle seçilen yola yazar', (t) async {
      final env = await _pump(t);
      env.chooser.saveLocation = '/masaustu/yedegim.db';

      await t.tap(find.text('Konum Seçerek Yedekle'));
      await t.pumpAndSettle();

      expect(env.chooser.suggestedNames.single, startsWith('cari_takip_manual_'));
      expect(env.backupService.created.single.targetPath, '/masaustu/yedegim.db');
    });

    testWidgets('konum seçimi iptal edilirse yedek alınmaz', (t) async {
      final env = await _pump(t);
      env.chooser.saveLocation = null;

      await t.tap(find.text('Konum Seçerek Yedekle'));
      await t.pumpAndSettle();

      expect(env.backupService.created, isEmpty);
    });

    testWidgets('yedek başarısız olursa kullanıcı dostu mesaj gösterir',
        (t) async {
      final env = await _pump(t);
      env.backupService.createError = makeInvalidBackupError();

      await t.tap(find.text('Yedek Oluştur'));
      await t.pumpAndSettle();

      expect(find.textContaining('geçerli bir SQLite'), findsOneWidget);
      // Düğmeler tekrar kullanılabilir.
      expect(
        t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Yedek Oluştur'))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('geri yükleme', () {
    testWidgets('dosya seçimi iptal edilirse hiçbir şey yapılmaz', (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = null;

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();

      expect(env.restoreService.validated, isEmpty);
      expect(env.restoreService.restored, isEmpty);
    });

    testWidgets('geçersiz dosya uyarı ile reddedilir, geri yükleme yapılmaz',
        (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = '/indirilenler/sahte.db';
      env.restoreService.validateError = makeInvalidBackupError();

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();

      expect(find.text('Geçersiz yedek dosyası'), findsOneWidget);
      expect(find.textContaining('geçerli bir SQLite'), findsOneWidget);
      expect(find.text('Yedekten geri yüklensin mi?'), findsNothing);
      expect(env.restoreService.restored, isEmpty);
    });

    testWidgets('onay ekranı yedeğin özetini gösterir; vazgeçilirse yüklenmez',
        (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = '/yedekler/eski_yedek.db';

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();

      expect(find.text('Yedekten geri yüklensin mi?'), findsOneWidget);
      expect(find.textContaining('eski_yedek.db'), findsOneWidget);
      expect(find.textContaining('12 cari, 340 finans hareketi'), findsOneWidget);

      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();

      expect(env.restoreService.restored, isEmpty);
    });

    testWidgets('onay kutusu işaretlenmeden geri yükle düğmesi etkin olmaz',
        (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = '/yedekler/eski_yedek.db';

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Geri Yükle');
      expect(t.widget<FilledButton>(button).onPressed, isNull);
      expect(env.restoreService.restored, isEmpty);
    });

    testWidgets('onaylanınca yüklenir, bilgi verilir ve uygulama yenilenir',
        (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = '/yedekler/eski_yedek.db';

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();
      await _tapRestoreConfirm(t);

      expect(env.restoreService.restored, ['/yedekler/eski_yedek.db']);
      expect(find.text('Geri yükleme tamamlandı'), findsOneWidget);

      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();

      // Uygulama baştan kuruldu: Dashboard'a dönüldü.
      expect(find.text('Aktif Cari'), findsOneWidget);
      expect(find.text('Yedekten Geri Yükle'), findsNothing);
    });

    testWidgets('yükleme başarısızsa ve yeniden başlatma gerekmiyorsa Ayarlar\'da kalır',
        (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = '/yedekler/eski_yedek.db';
      env.restoreService.restoreError = makeInvalidBackupError();

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();
      await _tapRestoreConfirm(t);

      expect(find.text('Geri yükleme başarısız'), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();

      expect(find.text('Yedekten Geri Yükle'), findsOneWidget);
      expect(find.text('Aktif Cari'), findsNothing);
    });

    testWidgets('veritabanı yeniden açıldıysa başarısız olsa da uygulama yenilenir',
        (t) async {
      final env = await _pump(t);
      env.chooser.backupFile = '/yedekler/eski_yedek.db';
      env.restoreService.restoreError = const RestoreException(
        'Geri yükleme tamamlanamadı. Mevcut verileriniz korundu.',
        requiresRestart: true,
      );

      await t.tap(find.text('Yedekten Geri Yükle'));
      await t.pumpAndSettle();
      await _tapRestoreConfirm(t);

      expect(find.textContaining('Mevcut verileriniz korundu'), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();

      expect(find.text('Aktif Cari'), findsOneWidget);
    });
  });

  group('veritabanı kontrolü', () {
    testWidgets('sağlamsa başarı mesajı gösterir', (t) async {
      await _pump(t);

      await t.tap(find.text('Veritabanı Kontrolü'));
      await t.pumpAndSettle();

      expect(find.textContaining('kontrolü başarılı'), findsOneWidget);
    });

    testWidgets('sorun varsa uyarır', (t) async {
      await _pump(t, integrityOk: false);

      await t.tap(find.text('Veritabanı Kontrolü'));
      await t.pumpAndSettle();

      expect(find.textContaining('sorun tespit edildi'), findsOneWidget);
    });
  });
}
