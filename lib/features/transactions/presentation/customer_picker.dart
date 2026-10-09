import 'package:cari_takip/features/customers/domain/customer.dart';
import 'package:cari_takip/features/customers/domain/customer_search.dart';
import 'package:flutter/material.dart';

/// Aranabilir cari seçim dialogu. Seçilen cariyi döndürür, vazgeçilirse `null`.
Future<Customer?> showCustomerPickerDialog(
  BuildContext context, {
  required List<Customer> customers,
  int? selectedId,
}) {
  return showDialog<Customer>(
    context: context,
    builder: (_) => _CustomerPickerDialog(
      customers: customers,
      selectedId: selectedId,
    ),
  );
}

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({required this.customers, this.selectedId});

  final List<Customer> customers;
  final int? selectedId;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  String _query = '';

  List<Customer> get _matches => widget.customers
      .where((customer) => customerMatchesQuery(customer, _query))
      .toList();

  @override
  Widget build(BuildContext context) {
    final matches = _matches;

    // Diyalog küçük pencerelerde ekran dışına taşmasın.
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width < 560 ? screen.width - 120 : 480.0;
    final height = screen.height < 760 ? screen.height * 0.5 : 420.0;

    return AlertDialog(
      title: const Text('Cari Seç'),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            TextField(
              key: const Key('customer-picker-search'),
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (_) {
                // Enter: listedeki ilk (en iyi) eşleşmeyi seç.
                final currentMatches = _matches;
                if (currentMatches.isNotEmpty) {
                  Navigator.of(context).pop(currentMatches.first);
                }
              },
              decoration: const InputDecoration(
                hintText: 'Ad, soyad, telefon veya vergi no ile ara',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Eşleşen cari bulunamadı.'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final customer = matches[index];
                        final detail = [customer.phone, customer.taxNumber]
                            .whereType<String>()
                            .join(' · ');
                        return ListTile(
                          selected: customer.id == widget.selectedId,
                          title: Text(customer.displayName),
                          subtitle: detail.isEmpty ? null : Text(detail),
                          onTap: () => Navigator.of(context).pop(customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

/// Form ve filtrelerde kullanılan "cari seç" alanı görünümü.
class CustomerSelector extends StatelessWidget {
  const CustomerSelector({
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.customer,
    this.errorText,
    this.onClear,
    super.key,
  });

  final String label;
  final String placeholder;
  final Customer? customer;
  final String? errorText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final selected = customer;
    final clear = onClear;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
          suffixIcon: selected != null && clear != null
              ? IconButton(
                  tooltip: 'Temizle',
                  icon: const Icon(Icons.close),
                  onPressed: clear,
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selected?.displayName ?? placeholder,
          overflow: TextOverflow.ellipsis,
          style: selected == null
              ? TextStyle(color: Theme.of(context).colorScheme.outline)
              : null,
        ),
      ),
    );
  }
}
