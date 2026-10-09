import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/currency.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/core/widgets/date_filter_field.dart';
import 'package:cari_takip/core/widgets/empty_state.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/reports/domain/report_filter.dart';
import 'package:cari_takip/features/reports/domain/report_result.dart';
import 'package:cari_takip/features/reports/presentation/report_providers.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transactions/presentation/customer_picker.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  int? _customerId;
  int? _typeId;
  DateTime? _from;
  DateTime? _to;
  String? _customerError;

  /// "Raporla"ya basıldığında uygulanan filtre; sonuçlar buna aittir.
  ReportFilter? _applied;

  ReportFilter? get _draft {
    final customerId = _customerId;
    if (customerId == null) return null;
    return ReportFilter(
      customerId: customerId,
      transactionTypeId: _typeId,
      fromDate: _from,
      toDate: _to,
    );
  }

  bool get _isStale => _applied != null && _draft != _applied;

  Future<void> _pickCustomer() async {
    final customers = await ref.read(allCustomersProvider.future);
    if (!mounted) return;
    final picked = await showCustomerPickerDialog(
      context,
      customers: customers,
      selectedId: _customerId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customerId = picked.id;
      _customerError = null;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? (isFrom ? _to : _from) ?? AppDate.today(),
      firstDate: isFrom ? DateTime(2000) : _from ?? DateTime(2000),
      lastDate: isFrom ? _to ?? DateTime(2100) : DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final date = AppDate.dateOnly(picked);
    setState(() {
      if (isFrom) {
        _from = date;
      } else {
        _to = date;
      }
    });
  }

  void _run() {
    final error = Validators.customer(_customerId);
    if (error != null) {
      setState(() => _customerError = error);
      return;
    }
    setState(() {
      _customerError = null;
      _applied = _draft;
    });
  }

  void _reset() {
    setState(() {
      _customerId = null;
      _typeId = null;
      _from = null;
      _to = null;
      _customerError = null;
      _applied = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = ref.watch(allCustomersProvider).value ?? const [];
    final types = ref.watch(allTransactionTypesProvider).value ?? const [];

    Customer? selected;
    for (final c in customers) {
      if (c.id == _customerId) selected = c;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Raporlar', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFilters(selected, types),
            ),
          ),
          if (_isStale) ...[
            const SizedBox(height: 8),
            Text(
              "Filtreler değişti. Güncel sonuç için 'Raporla'ya basın.",
              style: TextStyle(color: theme.colorScheme.tertiary),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: _buildResult(types)),
        ],
      ),
    );
  }

  Widget _buildFilters(Customer? selected, List<TransactionType> types) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: KeyedSubtree(
            key: const Key('report-customer'),
            child: CustomerSelector(
              label: 'Cari *',
              placeholder: 'Cari seçiniz',
              customer: selected,
              errorText: _customerError,
              onTap: _pickCustomer,
            ),
          ),
        ),
        DateFilterField(
          fieldKey: const Key('report-from'),
          label: 'Başlangıç',
          value: _from,
          onTap: () => _pickDate(isFrom: true),
          onClear: () => setState(() => _from = null),
        ),
        DateFilterField(
          fieldKey: const Key('report-to'),
          label: 'Bitiş',
          value: _to,
          onTap: () => _pickDate(isFrom: false),
          onClear: () => setState(() => _to = null),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            key: ValueKey('report-type-$_typeId'),
            initialValue: _typeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'İşlem Tipi',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(child: Text('Tüm tipler')),
              for (final type in types)
                DropdownMenuItem<int?>(
                  value: type.id,
                  child: Text(type.isActive ? type.name : '${type.name} (Pasif)'),
                ),
            ],
            onChanged: (id) => setState(() => _typeId = id),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: _run, child: const Text('Raporla')),
              const SizedBox(width: 8),
              TextButton(onPressed: _reset, child: const Text('Temizle')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult(List<TransactionType> types) {
    final applied = _applied;
    if (applied == null) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        message: "Rapor için cari seçip 'Raporla'ya basın.",
      );
    }

    final report = ref.watch(reportProvider(applied));
    if (report.hasError && !report.hasValue) {
      return ErrorView(
        message: ErrorMapper.userMessage(
          report.error!,
          stackTrace: report.stackTrace,
        ),
        onRetry: () => ref.invalidate(reportProvider(applied)),
      );
    }
    if (!report.hasValue) return const LoadingView();

    final result = report.value!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_summary(result, types), style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: result.rows.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  message: 'Seçilen filtrelere uygun kayıt bulunamadı.',
                )
              : _ReportTable(rows: result.rows),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text('${result.count} kayıt'),
              const Spacer(),
              Text(
                'Toplam: ${Currency.formatKurusToTl(result.totalKurus)}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _summary(ReportResult result, List<TransactionType> types) {
    final filter = result.filter;
    final from = filter.fromDate;
    final to = filter.toDate;

    final String dates;
    if (from != null && to != null) {
      dates = '${AppDate.formatDisplay(from)} - ${AppDate.formatDisplay(to)}';
    } else if (from != null) {
      dates = '${AppDate.formatDisplay(from)} ve sonrası';
    } else if (to != null) {
      dates = '${AppDate.formatDisplay(to)} ve öncesi';
    } else {
      dates = 'Tüm tarihler';
    }

    var typeName = 'Tüm tipler';
    for (final t in types) {
      if (t.id == filter.transactionTypeId) typeName = t.name;
    }

    return '${result.customerName} · $dates · $typeName';
  }
}

const _dateWidth = 110.0;
const _amountWidth = 150.0;

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.rows});

  final List<ReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: _dateWidth,
                  child: Text('Tarih', style: headerStyle),
                ),
                Expanded(flex: 2, child: Text('İşlem Tipi', style: headerStyle)),
                Expanded(flex: 3, child: Text('Not', style: headerStyle)),
                SizedBox(
                  width: _amountWidth,
                  child: Text(
                    'Tutar',
                    style: headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _dateWidth,
                        child: Text(AppDate.formatDisplay(row.transactionDate)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.transactionTypeName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.note ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: _amountWidth,
                        child: Text(
                          Currency.formatKurusToTl(row.amountKurus),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
