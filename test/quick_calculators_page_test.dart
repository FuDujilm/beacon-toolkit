import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/quick_calculators_page.dart';

void main() {
  testWidgets('quick calculators page renders core tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuickCalculatorsPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('快速计算'), findsWidgets);
    expect(find.text('欧姆定律'), findsWidgets);
    expect(find.text('功率 dB'), findsOneWidget);
    expect(find.text('SWR 回损'), findsOneWidget);
    expect(find.text('电压'), findsWidgets);
    expect(find.text('电流'), findsWidgets);
  });

  testWidgets('quick calculators page switches to power tab', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuickCalculatorsPage(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('功率 dB'));
    await tester.pumpAndSettle();

    expect(find.text('dBm'), findsWidgets);
    expect(find.text('dBW'), findsWidgets);
    expect(find.text('输入值'), findsOneWidget);
  });
}
