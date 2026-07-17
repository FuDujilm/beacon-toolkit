import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/antenna_calculator_page.dart';

void main() {
  testWidgets('antenna calculator page renders yagi entry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AntennaCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('天线计算器'), findsWidgets);
    expect(find.text('八木天线计算器'), findsOneWidget);
  });

  testWidgets('yagi calculator page renders blueprint and results', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: YagiAntennaCalculatorPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('八木天线计算器'), findsWidgets);
    expect(find.text('工作频率'), findsOneWidget);
    expect(find.textContaining('请输入 3-12 单元'), findsOneWidget);
    expect(find.text('元件直径'), findsOneWidget);
    expect(find.text('馈电间隙'), findsOneWidget);
    expect(find.text('boom 外径'), findsOneWidget);
    expect(find.text('安装方式'), findsOneWidget);
    expect(find.text('boom 材料'), findsOneWidget);
    expect(find.text('振子类型'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('设计蓝图预览'), findsOneWidget);
    expect(find.text('切割尺寸表'), findsOneWidget);
    expect(find.text('导向器 3'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('公差建议 ±0.5 mm'), findsOneWidget);
  });
}
