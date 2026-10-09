import 'dart:async';

import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/app_exception.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/form_shortcuts.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransactionTypeFormPage extends ConsumerStatefulWidget {
  const TransactionTypeFormPage({this.typeId, super.key});

  final int? typeId;

  @override
  ConsumerState<TransactionTypeFormPage> createState() =>
      _TransactionTypeFormPageState();
}

class _TransactionTypeFormPageState
    extends ConsumerState<TransactionTypeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  late bool _loading = widget.typeId != null;
  String? _loadError;
  String? _duplicateError;
  bool _saving = false;

  bool get _isEdit => widget.typeId != null;

  @override
  void initState() {
    super.initState();
    // Kullanıcı yazmaya başlayınca sunucu kaynaklı "aynı isim" hatası kalkar.
    _name.addListener(() => _duplicateError = null);
    if (_isEdit) unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _loadError = null;
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final type = await ref
          .read(transactionTypeRepositoryProvider)
          .getTransactionTypeById(widget.typeId!);
      if (!mounted) return;
      if (type == null) {
        setState(() => _loadError = 'İşlem tipi bulunamadı.');
        return;
      }
      _name.text = type.name;
      setState(() => _loading = false);
    } on Object catch (error, stack) {
      if (!mounted) return;
      setState(() {
        _loadError = ErrorMapper.userMessage(error, stackTrace: stack);
      });
    }
  }

  Future<void> _save() async {
    // Kısayolla ikinci kez tetiklenirse (kaydederken) yok say.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repository = ref.read(transactionTypeRepositoryProvider);

    try {
      if (_isEdit) {
        await repository.renameTransactionType(widget.typeId!, _name.text);
      } else {
        await repository.createTransactionType(_name.text);
      }
      ref.invalidate(transactionTypeListProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('İşlem tipi kaydedildi.')),
      );
      if (!mounted) return;
      router.go(AppRoutes.transactionTypes);
    } on Object catch (error, stack) {
      if (!mounted) return;
      final mapped = ErrorMapper.map(error, stackTrace: stack);
      setState(() => _saving = false);
      if (mapped.kind == AppErrorKind.duplicate) {
        _duplicateError = mapped.message;
        _formKey.currentState!.validate();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(mapped.message)));
      }
    }
  }

  void _cancel() => context.go(AppRoutes.transactionTypes);

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    if (error != null) return ErrorView(message: error, onRetry: _reload);
    if (_loading) return const LoadingView();

    return FormShortcuts(
      onSave: _saving ? null : _save,
      onCancel: _saving ? null : _cancel,
      child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'İşlem Tipi Düzenle' : 'Yeni İşlem Tipi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('field-name'),
                  controller: _name,
                  autofocus: !_isEdit,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) =>
                      _duplicateError ?? Validators.transactionTypeName(value),
                  onFieldSubmitted: (_) {
                    if (!_saving) unawaited(_save());
                  },
                  decoration: const InputDecoration(
                    labelText: 'İşlem Tipi Adı *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Kaydet'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _saving ? null : _cancel,
                      child: const Text('Vazgeç'),
                    ),
                  ],
                ),
                const FormShortcutHint(),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
