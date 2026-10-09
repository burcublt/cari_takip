import 'package:cari_takip/core/widgets/min_size_scroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  Widget? child,
  double minWidth = 400,
  double minHeight = 300,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MinSizeScroller(
          minWidth: minWidth,
          minHeight: minHeight,
          child: child ?? Container(key: const Key('content')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('yeterli alan varsa içerik kaydırıcısız ve tam boyutta gelir',
      (t) async {
    await _pump(t, const Size(800, 600));

    expect(t.getSize(find.byKey(const Key('content'))), const Size(800, 600));
    expect(
      find.descendant(
        of: find.byType(MinSizeScroller),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets('dar pencerede içerik en az minimum genişlikte kalır ve yatay '
      'kaydırılır', (t) async {
    await _pump(t, const Size(300, 600));

    expect(t.getSize(find.byKey(const Key('content'))), const Size(400, 600));
    final before = t.getTopLeft(find.byKey(const Key('content'))).dx;

    await t.drag(find.byType(SingleChildScrollView), const Offset(-80, 0));
    await t.pump();

    expect(t.getTopLeft(find.byKey(const Key('content'))).dx, lessThan(before));
  });

  testWidgets('kısa pencerede içerik en az minimum yükseklikte kalır ve '
      'dikey kaydırılır', (t) async {
    await _pump(t, const Size(800, 200));

    expect(t.getSize(find.byKey(const Key('content'))), const Size(800, 300));
    final before = t.getTopLeft(find.byKey(const Key('content'))).dy;

    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -60));
    await t.pump();

    expect(t.getTopLeft(find.byKey(const Key('content'))).dy, lessThan(before));
  });

  testWidgets('hem dar hem kısa pencerede minimum boyut korunur', (t) async {
    await _pump(t, const Size(300, 200));
    expect(t.getSize(find.byKey(const Key('content'))), const Size(400, 300));
    expect(t.takeException(), isNull);
  });

  testWidgets('içerideki ListView ile kaydırma çakışmaz', (t) async {
    await _pump(
      t,
      const Size(300, 200),
      child: ListView(
        children: [for (var i = 0; i < 60; i++) Text('Satır $i')],
      ),
    );

    expect(t.takeException(), isNull);

    await t.drag(find.byType(ListView), const Offset(0, -400));
    await t.pump();

    expect(t.takeException(), isNull);
    expect(find.text('Satır 0'), findsNothing);
  });

  testWidgets('pencere büyüyünce kaydırıcılar kalkar', (t) async {
    await _pump(t, const Size(300, 200));
    expect(find.byType(SingleChildScrollView), findsWidgets);

    t.view.physicalSize = const Size(900, 700);
    await t.pump();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(t.getSize(find.byKey(const Key('content'))), const Size(900, 700));
  });
}
