import 'package:flutter/material.dart';

/// İçeriğe en az [minWidth] x [minHeight] alan tanır. Mevcut alan bundan
/// küçükse içerik bu boyutta kalır ve yatay/dikey kaydırılabilir; böylece
/// çok küçük pencerelerde arayüz bozulmaz. Yeterli alan varsa [child] olduğu
/// gibi, kaydırıcısız gösterilir.
class MinSizeScroller extends StatefulWidget {
  const MinSizeScroller({
    required this.minWidth,
    required this.minHeight,
    required this.child,
    super.key,
  });

  final double minWidth;
  final double minHeight;
  final Widget child;

  @override
  State<MinSizeScroller> createState() => _MinSizeScrollerState();
}

class _MinSizeScrollerState extends State<MinSizeScroller> {
  // Açık denetleyiciler: içerideki sayfaların (ListView vb.) birincil
  // kaydırma denetleyicisiyle çakışmayı önler.
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needsHorizontal = constraints.maxWidth < widget.minWidth;
        final needsVertical = constraints.maxHeight < widget.minHeight;
        if (!needsHorizontal && !needsVertical) return widget.child;

        Widget content = SizedBox(
          width: needsHorizontal ? widget.minWidth : constraints.maxWidth,
          height: needsVertical ? widget.minHeight : constraints.maxHeight,
          child: widget.child,
        );
        if (needsVertical) {
          content = Scrollbar(
            controller: _vertical,
            child: SingleChildScrollView(
              controller: _vertical,
              child: content,
            ),
          );
        }
        if (needsHorizontal) {
          content = Scrollbar(
            controller: _horizontal,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }
}
