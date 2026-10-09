import 'dart:math' as math;

import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/currency.dart';
import 'package:cari_takip/core/widgets/empty_state.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/dashboard/domain/dashboard_summary.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);

    return summary.when(
      loading: () => const LoadingView(),
      error: (error, stack) => ErrorView(
        message: ErrorMapper.userMessage(error, stackTrace: stack),
        onRetry: () => ref.invalidate(dashboardSummaryProvider),
      ),
      data: (value) => _DashboardContent(summary: value),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  static const _spacing = 16.0;
  static const _minCardWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _StatCard(
        icon: Icons.people_outline,
        label: 'Aktif Cari',
        value: '${summary.activeCustomerCount}',
      ),
      _StatCard(
        icon: Icons.receipt_long_outlined,
        label: 'Toplam Hareket',
        value: '${summary.transactionCount}',
      ),
      _StatCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Genel Kayıtlı Tutar',
        value: Currency.formatKurusToTl(summary.totalAmountKurus),
      ),
      _StatCard(
        icon: Icons.calendar_month_outlined,
        label: 'Bu Ay Toplamı',
        value: Currency.formatKurusToTl(summary.monthAmountKurus),
        subtitle: '${AppDate.formatMonthYear(summary.month)} · '
            '${summary.monthTransactionCount} hareket',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Dashboard', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = math
                .max(1, (constraints.maxWidth / _minCardWidth).floor())
                .clamp(1, cards.length);
            final width =
                (constraints.maxWidth - _spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _RecentTransactionsCard(summary: summary),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = subtitle;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.headlineSmall),
            ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                note,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = summary.recentTransactions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Son Hareketler', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () => context.go(AppRoutes.transactions),
                    child: const Text('Tümünü Gör'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              _buildEmpty(context)
            else
              for (final t in items) _RecentRow(transaction: t),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final hasCustomers = summary.activeCustomerCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: hasCustomers
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Henüz finans hareketi eklenmedi.',
              actionLabel: 'Yeni Hareket Ekle',
              onAction: () => context.go('${AppRoutes.transactions}/new'),
            )
          : EmptyState(
              icon: Icons.people_outline,
              message: 'Başlamak için bir cari ekleyin.',
              actionLabel: 'Yeni Cari Ekle',
              onAction: () => context.go('${AppRoutes.customers}/new'),
            ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.transaction});

  final RecentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(AppDate.formatDisplay(transaction.transactionDate)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              transaction.customerName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              transaction.transactionTypeName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              Currency.formatKurusToTl(transaction.amountKurus),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
