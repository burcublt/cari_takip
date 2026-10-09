import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retry = onRetry;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.titleMedium),
          if (retry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: retry, child: const Text('Tekrar Dene')),
          ],
        ],
      ),
    );
  }
}
