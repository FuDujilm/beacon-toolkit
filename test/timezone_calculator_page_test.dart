import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/timezone_calculator_page.dart';

void main() {
  testWidgets('timezone calculator page renders core sections',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TimezoneCalculatorPage(),
      ),
    );

    await tester.pump();

    expect(find.text('时区计算'), findsWidgets);
    expect(find.text('双地点时区换算'), findsOneWidget);
    expect(find.text('地点 A'), findsWidgets);
    expect(find.text('地点 B'), findsWidgets);
    expect(find.text('底图'), findsOneWidget);
  });
}
