import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/widgets/empty_state.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/core/widgets/table_card.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_actions.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _newTypeRoute = '${AppRoutes.transactionTypes}/new';

class TransactionTypeListPage extends ConsumerWidget {
  const TransactionTypeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(transactionTypeStatusFilterProvider);
    final types = ref.watch(transactionTypeListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('İşlem Tipleri', style: theme.textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.go(_newTypeRoute),
                icon: const Icon(Icons.add),
                label: const Text('Yeni İşlem Tipi'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<TransactionTypeStatusFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TransactionTypeStatusFilter.active,
                label: Text('Aktif'),
              ),
              ButtonSegment(
                value: TransactionTypeStatusFilter.inactive,
                label: Text('Pasif'),
              ),
              ButtonSegment(
                value: TransactionTypeStatusFilter.all,
                label: Text('Tümü'),
              ),
            ],
            selected: {status},
            onSelectionChanged: (selection) => ref
                .read(transactionTypeStatusFilterProvider.notifier)
                .setStatus(selection.first),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(context, ref, status, types)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TransactionTypeStatusFilter status,
    AsyncValue<List<TransactionType>> types,
  ) {
    if (types.hasError && !types.hasValue) {
      return ErrorView(
        message: ErrorMapper.userMessage(
          types.error!,
          stackTrace: types.stackTrace,
        ),
        onRetry: () => ref.invalidate(transactionTypeListProvider),
      );
    }
    if (!types.hasValue) return const LoadingView();

    final items = types.value!;
    if (items.isEmpty) {
      if (status == TransactionTypeStatusFilter.inactive) {
        return const EmptyState(message: 'Pasif işlem tipi bulunmuyor.');
      }
      return EmptyState(
        icon: Icons.category_outlined,
        message: 'Henüz işlem tipi eklenmedi.',
        actionLabel: 'Yeni İşlem Tipi Ekle',
        onAction: () => context.go(_newTypeRoute),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return TableCard(
      columns: const [
        AppTableColumn('İşlem Tipi', flex: 3),
        AppTableColumn('Durum', width: 80),
        AppTableColumn('İşlemler', width: 110),
      ],
      itemCount: items.length,
      cellsBuilder: (context, index) {
        final type = items[index];
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              type.name,
              overflow: TextOverflow.ellipsis,
              style: type.isActive ? null : TextStyle(color: scheme.outline),
            ),
          ),
          Text(
            type.isActive ? 'Aktif' : 'Pasif',
            style: TextStyle(
              color: type.isActive ? scheme.primary : scheme.outline,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context
                    .go('${AppRoutes.transactionTypes}/${type.id}/edit'),
              ),
              IconButton(
                tooltip: type.isActive ? 'Pasife Al' : 'Aktif Et',
                icon: Icon(
                  type.isActive ? Icons.block : Icons.check_circle_outline,
                ),
                onPressed: () =>
                    toggleTransactionTypeActive(context, ref, type),
              ),
            ],
          ),
        ];
      },
    );
  }
}
