import 'package:cari_takip/core/database/database_provider.dart';
import 'package:cari_takip/features/reports/data/sqlite_report_repository.dart';
import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:cari_takip/features/reports/domain/report_repository.dart';
import 'package:cari_takip/features/reports/domain/report_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => SqliteReportRepository(ref.watch(appDatabaseProvider).db),
);

final reportProvider =
    FutureProvider.autoDispose.family<ReportResult, ReportFilter>((ref, filter) {
  return ref.watch(reportRepositoryProvider).getReport(filter);
});
