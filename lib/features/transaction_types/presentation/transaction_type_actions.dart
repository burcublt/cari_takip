import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/widgets/confirmation_dialog.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aktifse onay alarak pasife alır, pasifse doğrudan aktif eder.
Future<void> toggleTransactionTypeActive(
  BuildContext context,
  WidgetRef ref,
  TransactionType type,
) async {
  final messenger = ScaffoldMessenger.of(context);

  if (type.isActive) {
    final confirmed = await confirmDeactivateTransactionType(context, type.name);
    if (!confirmed || !context.mounted) return;
  }

  try {
    await ref
        .read(transactionTypeRepositoryProvider)
        .setTransactionTypeActive(type.id, isActive: !type.isActive);
    ref.invalidate(transactionTypeListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          type.isActive
              ? 'İşlem tipi pasife alındı.'
              : 'İşlem tipi aktif edildi.',
        ),
      ),
    );
  } on Object catch (error, stack) {
    messenger.showSnackBar(
      SnackBar(content: Text(ErrorMapper.userMessage(error, stackTrace: stack))),
    );
  }
}
