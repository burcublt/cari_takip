import 'package:flutter/material.dart';

class AppTableColumn {
  const AppTableColumn(
    this.label, {
    this.flex = 1,
    this.width,
    this.align = TextAlign.left,
  });

  final String label;

  /// [width] verilmezse kalan alan [flex] oranında paylaştırılır.
  final int flex;
  final double? width;
  final TextAlign align;
}

/// Başlığı sabit, satırları tembel (lazy) oluşturulan masaüstü tablosu.
/// Binlerce satırda bile akıcıdır; başlık kaydırırken görünür kalır.
class TableCard extends StatelessWidget {
  const TableCard({
    required this.columns,
    required this.itemCount,
    required this.cellsBuilder,
    super.key,
  });

  final List<AppTableColumn> columns;
  final int itemCount;

  /// Satırın hücreleri; sayısı [columns] ile aynı olmalıdır.
  final List<Widget> Function(BuildContext context, int index) cellsBuilder;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _layout([
              for (final c in columns)
                Text(
                  c.label,
                  style: headerStyle,
                  textAlign: c.align,
                  overflow: TextOverflow.ellipsis,
                ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: itemCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _layout(cellsBuilder(context, index)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layout(List<Widget> cells) {
    assert(cells.length == columns.length, 'Hücre sayısı kolon sayısına eşit olmalı');
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          if (columns[i].width != null)
            SizedBox(width: columns[i].width, child: cells[i])
          else
            Expanded(flex: columns[i].flex, child: cells[i]),
      ],
    );
  }
}
