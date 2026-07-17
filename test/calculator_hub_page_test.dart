import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/calculator_hub_page.dart';

void main() {
  testWidgets('calculator hub page renders categories and implemented items', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CalculatorHubPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('计算目录'), findsWidgets);
    expect(find.text('天线'), findsOneWidget);
    expect(find.text('传输线'), findsOneWidget);
    expect(find.text('快速计算'), findsNothing);
    expect(find.text('八木天线计算器'), findsOneWidget);
    expect(find.text('已接入'), findsWidgets);
    expect(find.text('目录项'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('传播'), findsOneWidget);
    expect(find.text('单位换算'), findsWidgets);
  });
}
