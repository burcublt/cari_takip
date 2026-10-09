import 'package:cari_takip/features/dashboard/domain/dashboard_repository.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_summary.dart';

RecentTransaction makeRecent({
  int id = 1,
  DateTime? date,
  String customerName = 'Ahmet Yılmaz',
  String typeName = 'Kira',
  int amountKurus = 125050,
}) {
  return RecentTransaction(
    id: id,
    transactionDate: date ?? DateTime(2026, 9, 15),
    customerName: customerName,
    transactionTypeName: typeName,
    amountKurus: amountKurus,
  );
}

DashboardSummary makeSummary({
  int activeCustomerCount = 0,
  int transactionCount = 0,
  int totalAmountKurus = 0,
  int monthAmountKurus = 0,
  int monthTransactionCount = 0,
  List<RecentTransaction> recent = const [],
}) {
  return DashboardSummary(
    activeCustomerCount: activeCustomerCount,
    transactionCount: transactionCount,
    totalAmountKurus: totalAmountKurus,
    month: DateTime(2026, 9),
    monthAmountKurus: monthAmountKurus,
    monthTransactionCount: monthTransactionCount,
    recentTransactions: recent,
  );
}

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository([DashboardSummary? summary])
      : summary = summary ?? makeSummary();

  DashboardSummary summary;

  @override
  Future<DashboardSummary> getSummary() async => summary;
}
