import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/currency.dart';
import 'package:cari_takip/core/widgets/confirmation_dialog.dart';
import 'package:cari_takip/core/widgets/date_filter_field.dart';
import 'package:cari_takip/core/widgets/empty_state.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/presentation/customer_picker.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({this.initialCustomerId, super.key});

  /// Cari detayından `?customerId=` ile gelindiğinde filtre önceden seçilir.
  final int? initialCustomerId;

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  late TransactionFilter _filter =
      TransactionFilter(customerId: widget.initialCustomerId);

  @override
  void didUpdateWidget(TransactionListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCustomerId != widget.initialCustomerId) {
      _filter = TransactionFilter(customerId: widget.initialCustomerId);
    }
  }

  String get _newRoute {
    final customerId = _filter.customerId;
    return customerId == null
        ? '${AppRoutes.transactions}/new'
        : '${AppRoutes.transactions}/new?customerId=$customerId';
  }

  Future<void> _pickCustomer() async {
    final customers = await ref.read(allCustomersProvider.future);
    if (!mounted) return;
    final picked = await showCustomerPickerDialog(
      context,
      customers: customers,
      selectedId: _filter.customerId,
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = _filter.withCustomer(picked.id));
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _filter.fromDate : _filter.toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ??
          (isFrom ? _filter.toDate : _filter.fromDate) ??
          AppDate.today(),
      firstDate: isFrom ? DateTime(2000) : _filter.fromDate ?? DateTime(2000),
      lastDate: isFrom ? _filter.toDate ?? DateTime(2100) : DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final date = AppDate.dateOnly(picked);
    setState(() {
      _filter = isFrom ? _filter.withFrom(date) : _filter.withTo(date);
    });
  }

  Future<void> _delete(FinancialTransaction transaction) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeleteTransaction(context);
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .deleteTransaction(transaction.id);
      invalidateTransactionData(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text('Finans hareketi silindi.')),
      );
    } on Object catch (error, stack) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.userMessage(error, stackTrace: stack)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = ref.watch(allCustomersProvider).value ?? const [];
    final types = ref.watch(allTransactionTypesProvider).value ?? const [];

    Customer? selectedCustomer;
    for (final c in customers) {
      if (c.id == _filter.customerId) selectedCustomer = c;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Finans Hareketleri', style: theme.textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                key: const Key('new-transaction-fab'),
                onPressed: () => context.go(_newRoute),
                icon: const Icon(Icons.add),
                label: const Text('Yeni Hareket Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilters(selectedCustomer, types),
          const SizedBox(height: 16),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters(
      Customer? selectedCustomer, List<TransactionType> types) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: KeyedSubtree(
            key: const Key('filter-customer'),
            child: CustomerSelector(
              label: 'Cari',
              placeholder: 'Tümü',
              customer: selectedCustomer,
              onTap: _pickCustomer,
              onClear: () =>
                  setState(() => _filter = _filter.withCustomer(null)),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            key: ValueKey('filter-type-${_filter.transactionTypeId}'),
            initialValue: _filter.transactionTypeId,
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
                  child:
                      Text(type.isActive ? type.name : '${type.name} (Pasif)'),
                ),
            ],
            onChanged: (id) => setState(() => _filter = _filter.withType(id)),
          ),
        ),
        DateFilterField(
          fieldKey: const Key('filter-from'),
          label: 'Başlangıç',
          value: _filter.fromDate,
          onTap: () => _pickDate(isFrom: true),
          onClear: () => setState(() => _filter = _filter.withFrom(null)),
        ),
        DateFilterField(
          fieldKey: const Key('filter-to'),
          label: 'Bitiş',
          value: _filter.toDate,
          onTap: () => _pickDate(isFrom: false),
          onClear: () => setState(() => _filter = _filter.withTo(null)),
        ),
        if (!_filter.isEmpty)
          TextButton(
            onPressed: () =>
                setState(() => _filter = const TransactionFilter()),
            child: const Text('Filtreleri Temizle'),
          ),
      ],
    );
  }

  Widget _buildList() {
    final list = ref.watch(transactionListProvider(_filter));
    final total = ref.watch(transactionTotalProvider(_filter));

    if (list.hasError && !list.hasValue) {
      return ErrorView(
        message: ErrorMapper.userMessage(
          list.error!,
          stackTrace: list.stackTrace,
        ),
        onRetry: () => invalidateTransactionData(ref),
      );
    }
    if (!list.hasValue) return const LoadingView();

    final items = list.value!;
    if (items.isEmpty) {
      if (_filter.isEmpty) {
        return EmptyState(
          icon: Icons.receipt_long_outlined,
          message: 'Henüz finans hareketi eklenmedi.',
          actionLabel: 'Yeni Hareket Ekle',
          onAction: () => context.go(_newRoute),
        );
      }
      return const EmptyState(
        icon: Icons.search_off,
        message: 'Seçilen filtrelere uygun kayıt bulunamadı.',
      );
    }

    final totalText =
        total.hasValue ? Currency.formatKurusToTl(total.value!) : '...';
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const _HeaderRow(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _TransactionRow(
                      transaction: items[index],
                      onEdit: () => context.go(
                        '${AppRoutes.transactions}/${items[index].id}/edit',
                      ),
                      onDelete: () => _delete(items[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            children: [
              Text('${items.length} kayıt'),
              Text(
                'Toplam: $totalText',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _dateWidth = 110.0;
const _amountWidth = 150.0;
const _actionsWidth = 100.0;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: _dateWidth, child: Text('Tarih', style: style)),
          Expanded(flex: 2, child: Text('Cari', style: style)),
          Expanded(flex: 2, child: Text('İşlem Tipi', style: style)),
          Expanded(flex: 3, child: Text('Not', style: style)),
          SizedBox(
            width: _amountWidth,
            child: Text('Tutar', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  final FinancialTransaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _dateWidth,
            child: Text(AppDate.formatDisplay(transaction.transactionDate)),
          ),
          Expanded(
            flex: 2,
            child:
                Text(transaction.customerName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(
              transaction.transactionTypeName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              transaction.note ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _amountWidth,
            child: Text(
              Currency.formatKurusToTl(transaction.amountKurus),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Düzenle',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
