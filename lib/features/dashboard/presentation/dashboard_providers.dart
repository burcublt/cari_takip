import 'package:cari_takip/core/database/database_provider.dart';
import 'package:cari_takip/features/dashboard/data/sqlite_dashboard_repository.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_repository.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => SqliteDashboardRepository(ref.watch(appDatabaseProvider).db),
);

/// autoDispose: Dashboard'a her dönüşte güncel veriler okunur.
final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).getSummary();
});
