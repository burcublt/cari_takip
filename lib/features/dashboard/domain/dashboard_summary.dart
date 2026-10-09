class RecentTransaction {
  const RecentTransaction({
    required this.id,
    required this.transactionDate,
    required this.customerName,
    required this.transactionTypeName,
    required this.amountKurus,
  });

  final int id;
  final DateTime transactionDate;
  final String customerName;
  final String transactionTypeName;
  final int amountKurus;
}

class DashboardSummary {
  const DashboardSummary({
    required this.activeCustomerCount,
    required this.transactionCount,
    required this.totalAmountKurus,
    required this.month,
    required this.monthAmountKurus,
    required this.monthTransactionCount,
    required this.recentTransactions,
  });

  /// `is_active = 1` olan cari sayısı.
  final int activeCustomerCount;

  /// Tüm finans hareketlerinin sayısı.
  final int transactionCount;

  /// Tüm hareketlerin toplamı (kuruş).
  final int totalAmountKurus;

  /// Aylık değerlerin hesaplandığı ay (günü anlamsız; yalnızca yıl/ay).
  final DateTime month;

  /// İşlem tarihi [month] içinde olan hareketlerin toplamı (kuruş).
  final int monthAmountKurus;
  final int monthTransactionCount;

  /// En yeni hareketler (tarih azalan, aynı tarihte id azalan).
  final List<RecentTransaction> recentTransactions;
}
