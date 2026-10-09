import 'package:cari_takip/features/reports/domain/report_filter.dart';

class ReportRow {
  const ReportRow({
    required this.id,
    required this.transactionDate,
    required this.transactionTypeName,
    required this.amountKurus,
    this.note,
  });

  final int id;
  final DateTime transactionDate;
  final String transactionTypeName;
  final int amountKurus;
  final String? note;
}

class ReportResult {
  const ReportResult({
    required this.filter,
    required this.customerName,
    required this.rows,
    required this.totalKurus,
  });

  final ReportFilter filter;
  final String customerName;
  final List<ReportRow> rows;

  /// Yalnızca aktif filtredeki kayıtların toplamı (kuruş).
  final int totalKurus;

  int get count => rows.length;
}
