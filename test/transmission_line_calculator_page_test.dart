import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/transmission_line_calculator_page.dart';

void main() {
  testWidgets('transmission line calculator page renders tool list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TransmissionLineCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('传输线'), findsWidgets);
    expect(find.text('同轴损耗'), findsWidgets);
    expect(find.text('SWR / 回波损耗'), findsOneWidget);
    expect(find.text('电气长度换算'), findsOneWidget);
    expect(find.text('四分之一波阻抗变换'), findsOneWidget);
    expect(find.text('同轴扼流圈匝数'), findsOneWidget);
    expect(find.textContaining('把传输线计算拆成独立工具页'), findsOneWidget);
  });

  testWidgets('coax loss page renders dedicated fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoaxLossCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('同轴损耗'), findsWidgets);
    expect(find.text('线缆类型'), findsOneWidget);
    expect(find.text('负载 SWR'), findsOneWidget);
    expect(find.text('匹配损耗'), findsOneWidget);
  });

  testWidgets('quarter wave page renders dedicated fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuarterWaveTransformerCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('四分之一波阻抗变换'), findsWidgets);
    expect(find.text('源阻抗'), findsOneWidget);
    expect(find.text('负载阻抗'), findsOneWidget);
    expect(find.text('所需特性阻抗'), findsOneWidget);
  });

  testWidgets('coax choke page renders dedicated fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoaxChokeTurnsCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('同轴扼流圈匝数'), findsWidgets);
    expect(find.text('磁环型号'), findsOneWidget);
    expect(find.text('目标扼流阻抗'), findsOneWidget);
    expect(find.text('建议整匝数'), findsOneWidget);
  });
}
