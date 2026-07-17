import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/radio_tools_page.dart';

void main() {
  testWidgets('radio tools page includes calculator hub and quick category', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RadioToolsPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('快速计算'), findsWidgets);
    expect(find.text('计算目录'), findsOneWidget);
    await tester.tap(find.text('快速计算').first);
    await tester.pumpAndSettle();
    expect(find.text('欧姆定律、功率 dB、SWR 回损快算'), findsOneWidget);
  });
}
