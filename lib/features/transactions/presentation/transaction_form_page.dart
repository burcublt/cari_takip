import 'dart:async';

import 'package:cari_takip/app/router.dart';
import 'package:cari_takip/core/errors/error_mapper.dart';
import 'package:cari_takip/core/utils/app_date.dart';
import 'package:cari_takip/core/utils/currency.dart';
import 'package:cari_takip/core/utils/validators.dart';
import 'package:cari_takip/core/widgets/error_view.dart';
import 'package:cari_takip/core/widgets/form_shortcuts.dart';
import 'package:cari_takip/core/widgets/loading_view.dart';
import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/presentation/customer_providers.dart';
import 'package:cari_takip/features/transaction_types/domain/transaction_type.dart';
import 'package:cari_takip/features/transaction_types/presentation/transaction_type_providers.dart';
import 'package:cari_takip/features/transactions/domain/financial_transaction.dart';
import 'package:cari_takip/features/transactions/presentation/customer_picker.dart';
import 'package:cari_takip/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    this.transactionId,
    this.initialCustomerId,
    super.key,
  });

  final int? transactionId;

  /// Cari detayından gelindiğinde cari önceden seçilir.
  final int? initialCustomerId;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateText = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  List<Customer> _customers = const [];
  List<TransactionType> _types = const [];
  int? _customerId;
  int? _typeId;
  TransactionDirection? _direction;
  DateTime _date = AppDate.today();

  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  bool get _isEdit => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _dateText.text = AppDate.formatDisplay(_date);
    unawaited(_load());
  }

  @override
  void dispose() {
    _dateText.dispose();
    _amount.dispose();
    _note.dispose();
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
      final customers = await ref
          .read(customerRepositoryProvider)
          .getCustomers(status: CustomerStatusFilter.all);
      final types = await ref
          .read(transactionTypeRepositoryProvider)
          .getTransactionTypes(status: TransactionTypeStatusFilter.all);

      int? customerId;
      FinancialTransaction? existing;
      if (_isEdit) {
        existing = await ref
            .read(transactionRepositoryProvider)
            .getTransactionById(widget.transactionId!);
        if (existing == null) {
          if (!mounted) return;
          setState(() => _loadError = 'Finans hareketi bulunamadı.');
          return;
        }
      } else {
        final initial = widget.initialCustomerId;
        final match = customers.where((c) => c.id == initial && c.isActive);
        customerId = match.isEmpty ? null : match.first.id;
      }

      if (!mounted) return;
      setState(() {
        _customers = customers;
        _types = types;
        if (existing != null) {
          _customerId = existing.customerId;
          _typeId = existing.transactionTypeId;
          _direction = existing.direction;
          _date = existing.transactionDate;
          _dateText.text = AppDate.formatDisplay(_date);
          _amount.text = Currency.formatKurusToTl(existing.amountKurus,
              includeUnit: false);
          _note.text = existing.note ?? '';
        } else {
          _customerId = customerId;
        }
        _loading = false;
      });
    } on Object catch (error, stack) {
      if (!mounted) return;
      setState(() {
        _loadError = ErrorMapper.userMessage(error, stackTrace: stack);
      });
    }
  }

  /// Yeni kayıtta yalnızca aktif cariler; düzenlemede seçili cari pasif olsa da dahil.
  List<Customer> get _selectableCustomers =>
      _customers.where((c) => c.isActive || c.id == _customerId).toList();

  /// Yeni kayıtta yalnızca aktif tipler; düzenlemede seçili tip pasif olsa da dahil.
  List<TransactionType> get _selectableTypes =>
      _types.where((t) => t.isActive || t.id == _typeId).toList();

  Customer? _customerById(int? id) {
    for (final c in _customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = AppDate.dateOnly(picked);
      _dateText.text = AppDate.formatDisplay(_date);
    });
  }

  Future<void> _save() async {
    // Kısayolla ikinci kez tetiklenirse (kaydederken) yok say.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repository = ref.read(transactionRepositoryProvider);
    final draft = TransactionDraft(
      customerId: _customerId!,
      transactionTypeId: _typeId!,
      direction: _direction!,
      transactionDate: _date,
      amountKurus: Currency.parseTlToKurus(_amount.text)!,
      note: _note.text,
    );

    try {
      final saved = _isEdit
          ? await repository.updateTransaction(widget.transactionId!, draft)
          : await repository.createTransaction(draft);
      invalidateTransactionData(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text('Finans hareketi kaydedildi.')),
      );
      if (!mounted) return;
      final fromCustomer = !_isEdit && widget.initialCustomerId != null;
      router.go(
        fromCustomer
            ? '${AppRoutes.customers}/${saved.customerId}'
            : AppRoutes.transactions,
      );
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
    final customerId = widget.initialCustomerId;
    context.go(
      !_isEdit && customerId != null
          ? '${AppRoutes.customers}/$customerId'
          : AppRoutes.transactions,
    );
  }

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
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEdit
                        ? 'Finans Hareketi Düzenle'
                        : 'Yeni Finans Hareketi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  FormField<int>(
                    key: const Key('field-customer'),
                    initialValue: _customerId,
                    validator: Validators.customer,
                    builder: (field) => CustomerSelector(
                      label: 'Cari *',
                      placeholder: 'Cari seçiniz',
                      customer: _customerById(field.value),
                      errorText: field.errorText,
                      onTap: () async {
                        final picked = await showCustomerPickerDialog(
                          context,
                          customers: _selectableCustomers,
                          selectedId: field.value,
                        );
                        if (picked == null) return;
                        field.didChange(picked.id);
                        setState(() => _customerId = picked.id);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('field-date'),
                    controller: _dateText,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Tarih *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionDirection>(
                    key: const Key('field-direction'),
                    initialValue: _direction,
                    isExpanded: true,
                    validator: (direction) => direction == null
                        ? 'Borç veya tahsilat seçiniz.'
                        : null,
                    onChanged: (direction) => _direction = direction,
                    decoration: const InputDecoration(
                      labelText: 'Hareket Türü *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final direction in TransactionDirection.values)
                        DropdownMenuItem<TransactionDirection>(
                          value: direction,
                          child: Text(direction.label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: const Key('field-type'),
                    initialValue: _typeId,
                    isExpanded: true,
                    validator: Validators.transactionType,
                    onChanged: (id) => _typeId = id,
                    decoration: const InputDecoration(
                      labelText: 'İşlem Tipi *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final type in _selectableTypes)
                        DropdownMenuItem<int>(
                          value: type.id,
                          child: Text(
                            type.isActive ? type.name : '${type.name} (Pasif)',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('field-amount'),
                    controller: _amount,
                    validator: Validators.amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tutar (TL) *',
                      hintText: '1.250,50',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('field-note'),
                    controller: _note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Not',
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
