import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:cari_takip/features/reports/domain/report_result.dart';

/// Hatalar `AppException` olarak fırlatılır. Satırlar `transaction_date DESC,
/// id DESC` sıralıdır.
abstract interface class ReportRepository {
  Future<ReportResult> getReport(ReportFilter filter);
}
