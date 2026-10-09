/// Rapor filtresi: cari zorunludur; tip ve tarihler opsiyoneldir.
/// Tarih aralığı uçlar dahildir. Riverpod family anahtarı olduğu için `==` vardır.
class ReportFilter {
  const ReportFilter({
    required this.customerId,
    this.transactionTypeId,
    this.fromDate,
    this.toDate,
  });

  final int customerId;
  final int? transactionTypeId;
  final DateTime? fromDate;
  final DateTime? toDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilter &&
          other.customerId == customerId &&
          other.transactionTypeId == transactionTypeId &&
          other.fromDate == fromDate &&
          other.toDate == toDate;

  @override
  int get hashCode =>
      Object.hash(customerId, transactionTypeId, fromDate, toDate);
}
