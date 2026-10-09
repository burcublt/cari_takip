import 'package:cari_takip/core/widgets/table_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {int itemCount = 1000}) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TableCard(
            columns: const [
              AppTableColumn('Ad', flex: 2),
              AppTableColumn('Not'),
              AppTableColumn('Tutar', width: 100, align: TextAlign.right),
            ],
            itemCount: itemCount,
            cellsBuilder: (context, i) => [
              Text('Satır $i'),
              Text('Not $i'),
              Text('${i * 100} TL', textAlign: TextAlign.right),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('başlık ve ilk satırları gösterir', (t) async {
    await _pump(t);

    expect(find.text('Ad'), findsOneWidget);
    expect(find.text('Not'), findsOneWidget);
    expect(find.text('Tutar'), findsOneWidget);
    expect(find.text('Satır 0'), findsOneWidget);
    expect(find.text('0 TL'), findsOneWidget);
  });

  testWidgets('satırlar tembel oluşturulur (binlerce kayıtta akıcı)',
      (t) async {
    await _pump(t);

    expect(find.text('Satır 999'), findsNothing);
    expect(find.textContaining('Satır ').evaluate().length, lessThan(60));
  });

  testWidgets('kaydırınca başlık sabit kalır, son satıra ulaşılır', (t) async {
    await _pump(t);

    await t.scrollUntilVisible(
      find.text('Satır 999'),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 120,
    );

    expect(find.text('Satır 999'), findsOneWidget);
    expect(find.text('Satır 0'), findsNothing);
    expect(find.text('Ad'), findsOneWidget);
    expect(find.text('Tutar'), findsOneWidget);
  });

  testWidgets('sabit genişlikli kolon belirtilen genişliği alır', (t) async {
    await _pump(t, itemCount: 3);

    final cell = find.ancestor(
      of: find.text('0 TL'),
      matching: find.byType(SizedBox),
    );
    expect(
      cell.evaluate().any(
            (e) => (e.widget as SizedBox).width == 100,
          ),
      isTrue,
    );
  });

  testWidgets('hiç satır yoksa yalnızca başlık gösterilir', (t) async {
    await _pump(t, itemCount: 0);

    expect(find.text('Ad'), findsOneWidget);
    expect(find.textContaining('Satır '), findsNothing);
  });
}
