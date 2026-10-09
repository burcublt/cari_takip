import 'package:cari_takip/app/app_shell.dart';
import 'package:cari_takip/features/customers/presentation/customer_detail_page.dart';
import 'package:cari_takip/features/customers/presentation/customer_form_page.dart';
import 'package:cari_takip/features/customers/presentation/customer_list_page.dart';
import 'package:cari_takip/features/dashboard/presentation/dashboard_page.dart';
import 'package:cari_takip/features/reports/presentation/report_page.dart';
import 'package:cari_takip/features/settings/presentation/settings_page.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_form_page.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_list_page.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_form_page.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_list_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const dashboard = '/dashboard';
  static const customers = '/customers';
  static const transactions = '/transactions';
  static const transactionTypes = '/transaction-types';
  static const reports = '/reports';
  static const settings = '/settings';
}

int _id(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

int? _queryInt(GoRouterState state, String key) =>
    int.tryParse(state.uri.queryParameters[key] ?? '');

NoTransitionPage<void> _noTransitionPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.customers,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const CustomerListPage()),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CustomerFormPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    CustomerDetailPage(customerId: _id(state)),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) =>
                        CustomerFormPage(customerId: _id(state)),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.transactions,
            pageBuilder: (context, state) => _noTransitionPage(
              state,
              TransactionListPage(
                initialCustomerId: _queryInt(state, 'customerId'),
              ),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => TransactionFormPage(
                  initialCustomerId: _queryInt(state, 'customerId'),
                ),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) =>
                    TransactionFormPage(transactionId: _id(state)),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.transactionTypes,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TransactionTypeListPage()),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const TransactionTypeFormPage(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) =>
                    TransactionTypeFormPage(typeId: _id(state)),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const ReportPage()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const SettingsPage()),
          ),
        ],
      ),
    ],
  );
});
