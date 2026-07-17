import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:mobile/pages/radio/other_calculators_page.dart';

void main() {
  testWidgets('other calculators page renders mirror frequency entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OtherCalculatorsPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('其他计算器'), findsWidgets);
    expect(find.text('镜像频率计算器'), findsOneWidget);
    expect(find.text('互调计算器'), findsOneWidget);
  });

  testWidgets('mirror frequency page renders core fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MirrorFrequencyCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('镜像频率计算器'), findsWidgets);
    expect(find.text('信号频率'), findsOneWidget);
    expect(find.text('中频'), findsOneWidget);
    expect(find.text('高侧注入'), findsWidgets);
    expect(find.text('低侧注入'), findsOneWidget);
    expect(find.text('本振频率'), findsOneWidget);
    expect(find.text('镜像频率'), findsOneWidget);
    expect(find.byType(Math), findsWidgets);
  });

  testWidgets('intermodulation page renders core fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IntermodulationCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('互调计算器'), findsWidgets);
    expect(find.text('新增频率'), findsOneWidget);
    expect(find.text('添加频率'), findsOneWidget);
    expect(find.text('计算三阶互调'), findsOneWidget);
    expect(find.text('计算五阶互调'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('互调产物'), findsOneWidget);
    expect(find.textContaining('2f1 - f2'), findsOneWidget);
    expect(find.textContaining('145.5000 MHz'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('什么是互调'), findsOneWidget);
    expect(find.byType(Math, skipOffstage: false), findsWidgets);
  });

  testWidgets('intermodulation settings page renders focus modes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IntermodulationCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('关注频率'), findsOneWidget);
    expect(find.text('起止频率'), findsOneWidget);
    expect(find.text('中心频率'), findsOneWidget);
  });
}
