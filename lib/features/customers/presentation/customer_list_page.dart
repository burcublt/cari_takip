import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/currency.dart';
import 'package:cari_takip/core/widgets/confirmation_dialog.dart';
import 'package:cari_takip/core/widgets/empty_state.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/core/widgets/table_card.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_actions.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _newCustomerRoute = '${AppRoutes.customers}/new';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  late final TextEditingController _search;
  bool _checkingAccountingFees = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(customerListFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _checkAccountingFees() async {
    if (_checkingAccountingFees) return;
    setState(() => _checkingAccountingFees = true);

    final messenger = ScaffoldMessenger.of(context);
    var createdCount = 0;
    try {
      final today = AppDate.today();
      final types = await ref
          .read(transactionTypeRepositoryProvider)
          .getTransactionTypes(status: TransactionTypeStatusFilter.all);
      TransactionType? accountingFeeType;
      for (final type in types) {
        if (type.name.trim() == 'Muhasebe Ücreti' && type.isActive) {
          accountingFeeType = type;
          break;
        }
      }
      if (accountingFeeType == null) {
        throw StateError('Aktif "Muhasebe Ücreti" işlem tipi bulunamadı.');
      }

      final customers = await ref
          .read(customerRepositoryProvider)
          .getCustomers(status: CustomerStatusFilter.all);
      final monthTransactions =
          await ref.read(transactionRepositoryProvider).getTransactions(
                filter: TransactionFilter(
                  transactionTypeId: accountingFeeType.id,
                  fromDate: AppDate.startOfMonth(today),
                  toDate: AppDate.endOfMonth(today),
                ),
              );
      final customersWithDebt = monthTransactions
          .where((transaction) =>
              transaction.direction == TransactionDirection.debt)
          .map((transaction) => transaction.customerId)
          .toSet();
      final missingCustomers = customers.where((customer) {
        final fee = customer.accountingFeeKurus;
        return fee != null &&
            fee > 0 &&
            !customersWithDebt.contains(customer.id);
      }).toList();

      if (!mounted) return;
      if (missingCustomers.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Bu ay için oluşturulması gereken muhasebe ücreti borcu yok.',
            ),
          ),
        );
        return;
      }

      final totalKurus = missingCustomers.fold<int>(
        0,
        (total, customer) => total + customer.accountingFeeKurus!,
      );
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Muhasebe Ücretleri Oluşturulsun mu?',
        message: '${missingCustomers.length} cari için '
            '${Currency.formatKurusToTl(totalKurus)} tutarında '
            '${AppDate.formatMonthYear(today)} muhasebe ücreti borcu '
            'oluşturulacak.',
        confirmLabel: 'Borçları Oluştur',
      );
      if (!confirmed || !mounted) return;

      final repository = ref.read(transactionRepositoryProvider);
      for (final customer in missingCustomers) {
        await repository.createTransaction(
          TransactionDraft(
            customerId: customer.id,
            transactionTypeId: accountingFeeType.id,
            direction: TransactionDirection.debt,
            transactionDate: today,
            amountKurus: customer.accountingFeeKurus!,
            note: '${AppDate.formatMonthYear(today)} muhasebe ücreti',
          ),
        );
        createdCount++;
      }
      invalidateTransactionData(ref);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$createdCount cari için muhasebe ücreti borcu oluşturuldu.',
          ),
        ),
      );
    } on Object catch (error, stack) {
      if (createdCount > 0) invalidateTransactionData(ref);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.userMessage(error, stackTrace: stack)),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingAccountingFees = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(customerListFilterProvider);
    final customers = ref.watch(customerListProvider);
    final notifier = ref.read(customerListFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cariler', style: theme.textTheme.headlineSmall),
              const Spacer(),
              OutlinedButton.icon(
                key: const Key('check-accounting-fees'),
                onPressed:
                    _checkingAccountingFees ? null : _checkAccountingFees,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Muhasebe Ücreti Kontrol Et'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => context.go(_newCustomerRoute),
                icon: const Icon(Icons.add),
                label: const Text('Yeni Cari'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 380,
                child: TextField(
                  key: const Key('customer-search'),
                  controller: _search,
                  onChanged: notifier.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Ad, soyad, telefon veya vergi no ile ara',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              notifier.setQuery('');
                            },
                          ),
                  ),
                ),
              ),
              SegmentedButton<CustomerStatusFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CustomerStatusFilter.active,
                    label: Text('Aktif'),
                  ),
                  ButtonSegment(
                    value: CustomerStatusFilter.inactive,
                    label: Text('Pasif'),
                  ),
                  ButtonSegment(
                    value: CustomerStatusFilter.all,
                    label: Text('Tümü'),
                  ),
                ],
                selected: {filter.status},
                onSelectionChanged: (selection) =>
                    notifier.setStatus(selection.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(filter, customers)),
        ],
      ),
    );
  }

  Widget _buildBody(
    CustomerListFilter filter,
    AsyncValue<List<Customer>> customers,
  ) {
    if (customers.hasError && !customers.hasValue) {
      return ErrorView(
        message: ErrorMapper.userMessage(
          customers.error!,
          stackTrace: customers.stackTrace,
        ),
        onRetry: () => ref.invalidate(customerListProvider),
      );
    }
    if (!customers.hasValue) return const LoadingView();

    final items = customers.value!;
    if (items.isEmpty) return _buildEmpty(filter);

    return _CustomerTable(
      customers: items,
      onToggleActive: (customer) =>
          toggleCustomerActive(context, ref, customer),
    );
  }

  Widget _buildEmpty(CustomerListFilter filter) {
    if (filter.query.trim().isNotEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        message: 'Aramanıza uygun cari bulunamadı.',
      );
    }
    if (filter.status == CustomerStatusFilter.inactive) {
      return const EmptyState(message: 'Pasif cari bulunmuyor.');
    }
    return EmptyState(
      icon: Icons.people_outline,
      message: 'Henüz cari eklenmedi.',
      actionLabel: 'Yeni Cari Ekle',
      onAction: () => context.go(_newCustomerRoute),
    );
  }
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({
    required this.customers,
    required this.onToggleActive,
  });

  final List<Customer> customers;
  final void Function(Customer customer) onToggleActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TableCard(
      columns: const [
        AppTableColumn('Ad / Soyad', flex: 3),
        AppTableColumn('Telefon', flex: 2),
        AppTableColumn('Muhasebe Ücreti', flex: 2),
        AppTableColumn('Vergi No', flex: 2),
        AppTableColumn('Durum', width: 80),
        AppTableColumn('İşlemler', width: 150),
      ],
      itemCount: customers.length,
      cellsBuilder: (context, index) {
        final customer = customers[index];
        final detailRoute = '${AppRoutes.customers}/${customer.id}';
        return [
          InkWell(
            onTap: () => context.go(detailRoute),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                customer.displayName,
                overflow: TextOverflow.ellipsis,
                style:
                    customer.isActive ? null : TextStyle(color: scheme.outline),
              ),
            ),
          ),
          Text(customer.phone ?? '-', overflow: TextOverflow.ellipsis),
          Text(
            Currency.formatKurusToTl(customer.accountingFeeKurus ?? 0),
          ),
          Text(customer.taxNumber ?? '-', overflow: TextOverflow.ellipsis),
          Text(
            customer.isActive ? 'Aktif' : 'Pasif',
            style: TextStyle(
              color: customer.isActive ? scheme.primary : scheme.outline,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Detay',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => context.go(detailRoute),
              ),
              IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.go('$detailRoute/edit'),
              ),
              IconButton(
                tooltip: customer.isActive ? 'Pasife Al' : 'Aktif Et',
                icon: Icon(
                  customer.isActive ? Icons.block : Icons.check_circle_outline,
                ),
                onPressed: () => onToggleActive(customer),
              ),
            ],
          ),
        ];
      },
    );
  }
}
