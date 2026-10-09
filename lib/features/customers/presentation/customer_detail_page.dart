import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/currency.dart';
import 'package:cari_takip/core/widgets/empty_state.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_actions.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({required this.customerId, super.key});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerDetailProvider(customerId));

    return customer.when(
      loading: () => const LoadingView(),
      error: (error, stack) => ErrorView(
        message: ErrorMapper.userMessage(error, stackTrace: stack),
        onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
      ),
      data: (value) => value == null
          ? const EmptyState(
              icon: Icons.person_off_outlined,
              message: 'Cari bulunamadı.',
            )
          : _DetailContent(customer: value),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(customerSummaryProvider(customer.id));
    final base = '${AppRoutes.customers}/${customer.id}';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AppRoutes.customers),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Cariler'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                customer.displayName,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 12),
            Chip(label: Text(customer.isActive ? 'Aktif' : 'Pasif')),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => context.go('$base/edit'),
              child: const Text('Düzenle'),
            ),
            OutlinedButton(
              onPressed: () => toggleCustomerActive(context, ref, customer),
              child: Text(customer.isActive ? 'Pasife Al' : 'Aktif Et'),
            ),
            OutlinedButton(
              onPressed: customer.isActive
                  ? () => context.go(
                        '${AppRoutes.transactions}/new'
                        '?customerId=${customer.id}',
                      )
                  : null,
              child: const Text('Yeni Hareket Ekle'),
            ),
            OutlinedButton(
              onPressed: () => context.go(
                '${AppRoutes.transactions}?customerId=${customer.id}',
              ),
              child: const Text('Tüm Hareketleri Gör'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: 'Cari Bilgileri',
          child: Column(
            children: [
              _InfoRow('Telefon', customer.phone),
              _InfoRow('Vergi Numarası', customer.taxNumber),
              _InfoRow('Vergi Dairesi', customer.taxOffice),
              _InfoRow('Adres', customer.address),
              _InfoRow('Not', customer.note),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Hareket Özeti',
          child: summary.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (error, stack) =>
                Text(ErrorMapper.userMessage(error, stackTrace: stack)),
            data: (value) => Column(
              children: [
                _InfoRow(
                  'Toplam hareket tutarı',
                  Currency.formatKurusToTl(value.totalKurus),
                ),
                _InfoRow('Hareket sayısı', '${value.transactionCount}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Son Finans Hareketleri',
          child: _RecentTransactions(customerId: customer.id),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: Text(text == null || text.isEmpty ? '-' : text)),
        ],
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(customerRecentTransactionsProvider(customerId));

    return transactions.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stack) =>
          Text(ErrorMapper.userMessage(error, stackTrace: stack)),
      data: (items) {
        if (items.isEmpty) {
          return const Text('Bu cariye ait finans hareketi bulunmuyor.');
        }
        return Column(
          children: [
            for (final t in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(AppDate.formatDisplay(t.transactionDate)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        t.transactionTypeName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        t.note ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        Currency.formatKurusToTl(t.amountKurus),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
