/// Listelerde gösterilen finans hareketi (cari ve tip adlarıyla birlikte).
class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.transactionTypeId,
    required this.transactionTypeName,
    required this.transactionDate,
    required this.amountKurus,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final int id;
  final int customerId;
  final String customerName;
  final int transactionTypeId;
  final String transactionTypeName;

  /// Yalnızca tarih (saat bilgisi yok).
  final DateTime transactionDate;

  /// Her zaman kuruş cinsinden ve `> 0`.
  final int amountKurus;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Oluşturma/güncelleme için kullanıcı girdisi.
class TransactionDraft {
  const TransactionDraft({
    required this.customerId,
    required this.transactionTypeId,
    required this.transactionDate,
    required this.amountKurus,
    this.note,
  });

  final int customerId;
  final int transactionTypeId;
  final DateTime transactionDate;
  final int amountKurus;
  final String? note;
}

/// Liste filtresi. Tarihler dahildir (`from <= tarih <= to`).
/// Riverpod family anahtarı olarak kullanıldığı için `==` tanımlıdır.
class TransactionFilter {
  const TransactionFilter({
    this.customerId,
    this.transactionTypeId,
    this.fromDate,
    this.toDate,
  });

  final int? customerId;
  final int? transactionTypeId;
  final DateTime? fromDate;
  final DateTime? toDate;

  bool get isEmpty =>
      customerId == null &&
      transactionTypeId == null &&
      fromDate == null &&
      toDate == null;

  TransactionFilter withCustomer(int? id) => TransactionFilter(
        customerId: id,
        transactionTypeId: transactionTypeId,
        fromDate: fromDate,
        toDate: toDate,
      );

  TransactionFilter withType(int? id) => TransactionFilter(
        customerId: customerId,
        transactionTypeId: id,
        fromDate: fromDate,
        toDate: toDate,
      );

  TransactionFilter withFrom(DateTime? date) => TransactionFilter(
        customerId: customerId,
        transactionTypeId: transactionTypeId,
        fromDate: date,
        toDate: toDate,
      );

  TransactionFilter withTo(DateTime? date) => TransactionFilter(
        customerId: customerId,
        transactionTypeId: transactionTypeId,
        fromDate: fromDate,
        toDate: date,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilter &&
          other.customerId == customerId &&
          other.transactionTypeId == transactionTypeId &&
          other.fromDate == fromDate &&
          other.toDate == toDate;

  @override
  int get hashCode =>
      Object.hash(customerId, transactionTypeId, fromDate, toDate);
}
