import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Form klavye davranışları: Esc = vazgeç, Ctrl/Cmd + Enter = kaydet.
/// Callback `null` ise ilgili kısayol devre dışıdır (ör. kaydederken).
class FormShortcuts extends StatelessWidget {
  const FormShortcuts({
    required this.child,
    this.onSave,
    this.onCancel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final save = onSave;
    final cancel = onCancel;
    return CallbackShortcuts(
      bindings: {
        if (save != null) ...{
          const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): save,
          const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
              save,
          const SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true):
              save,
        },
        if (cancel != null)
          const SingleActivator(LogicalKeyboardKey.escape): cancel,
      },
      child: child,
    );
  }
}

/// Formun altında gösterilen kısayol ipucu.
class FormShortcutHint extends StatelessWidget {
  const FormShortcutHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final save = defaultTargetPlatform == TargetPlatform.macOS
        ? '⌘ + Enter'
        : 'Ctrl + Enter';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Kaydet: $save · Vazgeç: Esc',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
