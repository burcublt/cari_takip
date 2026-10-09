import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/widgets/confirmation_dialog.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aktifse onay alarak pasife alır, pasifse doğrudan aktif eder.
Future<void> toggleCustomerActive(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
) async {
  final messenger = ScaffoldMessenger.of(context);

  if (customer.isActive) {
    final confirmed =
        await confirmDeactivateCustomer(context, customer.displayName);
    if (!confirmed || !context.mounted) return;
  }

  try {
    await ref
        .read(customerRepositoryProvider)
        .setCustomerActive(customer.id, isActive: !customer.isActive);
    ref
      ..invalidate(customerListProvider)
      ..invalidate(customerDetailProvider(customer.id));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          customer.isActive ? 'Cari pasife alındı.' : 'Cari aktif edildi.',
        ),
      ),
    );
  } on Object catch (error, stack) {
    messenger.showSnackBar(
      SnackBar(content: Text(ErrorMapper.userMessage(error, stackTrace: stack))),
    );
  }
}
