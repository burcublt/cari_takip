import 'dart:async';

import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/form_shortcuts.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({this.customerId, super.key});

  final int? customerId;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _taxNumber = TextEditingController();
  final _taxOffice = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  late bool _loading = widget.customerId != null;
  String? _loadError;
  bool _saving = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _taxNumber,
      _taxOffice,
      _address,
      _note,
    ]) {
      controller.dispose();
    }
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
      final customer = await ref
          .read(customerRepositoryProvider)
          .getCustomerById(widget.customerId!);
      if (!mounted) return;
      if (customer == null) {
        setState(() => _loadError = 'Cari bulunamadı.');
        return;
      }
      _firstName.text = customer.firstName;
      _lastName.text = customer.lastName ?? '';
      _phone.text = customer.phone ?? '';
      _taxNumber.text = customer.taxNumber ?? '';
      _taxOffice.text = customer.taxOffice ?? '';
      _address.text = customer.address ?? '';
      _note.text = customer.note ?? '';
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
    final repository = ref.read(customerRepositoryProvider);
    final draft = CustomerDraft.fromForm(
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
      taxNumber: _taxNumber.text,
      taxOffice: _taxOffice.text,
      address: _address.text,
      note: _note.text,
    );

    try {
      final saved = _isEdit
          ? await repository.updateCustomer(widget.customerId!, draft)
          : await repository.createCustomer(draft);
      ref
        ..invalidate(customerListProvider)
        ..invalidate(customerDetailProvider(saved.id));
      messenger.showSnackBar(const SnackBar(content: Text('Cari kaydedildi.')));
      if (!mounted) return;
      router.go('${AppRoutes.customers}/${saved.id}');
    } on Object catch (error, stack) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.userMessage(error, stackTrace: stack)),
        ),
      );
    }
  }

  void _cancel() {
    final id = widget.customerId;
    context.go(id == null ? AppRoutes.customers : '${AppRoutes.customers}/$id');
  }

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    if (error != null) {
      return ErrorView(message: error, onRetry: _reload);
    }
    if (_loading) return const LoadingView();

    return FormShortcuts(
      onSave: _saving ? null : _save,
      onCancel: _saving ? null : _cancel,
      child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Cari Düzenle' : 'Yeni Cari',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                _field(
                  'field-firstName',
                  _firstName,
                  'Ad / Unvan *',
                  validator: Validators.customerName,
                  autofocus: !_isEdit,
                ),
                _field('field-lastName', _lastName, 'Soyad'),
                _field('field-phone', _phone, 'Telefon'),
                _field('field-taxNumber', _taxNumber, 'Vergi Numarası'),
                _field('field-taxOffice', _taxOffice, 'Vergi Dairesi'),
                _field('field-address', _address, 'Adres', maxLines: 2),
                _field('field-note', _note, 'Not', maxLines: 3),
                const SizedBox(height: 8),
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

  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: Key(key),
        controller: controller,
        maxLines: maxLines,
        autofocus: autofocus,
        // Enter: sonraki alana geç (çok satırlı alanlarda yeni satır).
        textInputAction:
            maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
