import 'package:cari_takip/core/utils/app_date.dart';
import 'package:flutter/material.dart';

/// Tarih filtresi alanı: dokununca seçici açılır, seçiliyse temizlenebilir.
class DateFilterField extends StatelessWidget {
  const DateFilterField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    super.key,
  });

  final Key fieldKey;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final date = value;
    return SizedBox(
      width: 170,
      child: InkWell(
        key: fieldKey,
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: date == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  ),
          ),
          child: Text(
            date == null ? 'Seçiniz' : AppDate.formatDisplay(date),
            style: date == null
                ? TextStyle(color: Theme.of(context).colorScheme.outline)
                : null,
          ),
        ),
      ),
    );
  }
}
