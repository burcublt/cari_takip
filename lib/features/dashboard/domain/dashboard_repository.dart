import 'package:cari_takip/features/dashboard/domain/dashboard_summary.dart';

/// Hatalar `AppException` olarak fırlatılır.
abstract interface class DashboardRepository {
  Future<DashboardSummary> getSummary();
}
