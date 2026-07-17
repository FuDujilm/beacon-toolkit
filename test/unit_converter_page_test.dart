import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/radio/unit_converter_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unit converter page renders power mode by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnitConverterPage(),
      ),
    );

    await tester.pump();

    expect(find.text('单位换算'), findsWidgets);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('频率'), findsWidgets);
    expect(find.text('波长'), findsOneWidget);
    expect(find.text('电压功率'), findsOneWidget);
    expect(find.text('场强通量'), findsOneWidget);
  });

  testWidgets('wavelength mode renders wavelength section', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnitConverterPage(),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('波长').first);
    await tester.pumpAndSettle();

    expect(find.text('波长'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('field flux mode renders frequency and impedance controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnitConverterPage(),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('场强通量').first);
    await tester.pumpAndSettle();

    expect(find.text('频率'), findsWidgets);
    expect(find.text('阻抗'), findsOneWidget);
    expect(find.text('场强'), findsOneWidget);
    expect(find.text('通量密度'), findsOneWidget);
    expect(find.text('功率'), findsOneWidget);
  });

  testWidgets('power voltage fields use two-column rows on normal mobile width',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: UnitConverterPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Row), findsWidgets);
    expect(find.text('μV'), findsNothing);
  });

  testWidgets('content stays constrained on desktop width', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: UnitConverterPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(ConstrainedBox), findsWidgets);
    final constrainedBoxes = tester.widgetList<ConstrainedBox>(
      find.byType(ConstrainedBox),
    );
    expect(
      constrainedBoxes.any(
        (box) => box.constraints.maxWidth == 520,
      ),
      isTrue,
    );
    expect(
      constrainedBoxes.any(
        (box) => box.constraints.maxWidth == 760,
      ),
      isTrue,
    );
  });

  testWidgets('editing source field keeps cursor position', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnitConverterPage(),
      ),
    );

    await tester.pump();

    final firstValueField = find.byType(TextField).at(1);
    await tester.tap(firstValueField);
    await tester.pump();

    final state =
        tester.state<EditableTextState>(find.byType(EditableText).at(1));
    state.updateEditingValue(
      const TextEditingValue(
        text: '13.8500',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();

    expect(state.textEditingValue.selection.baseOffset, 5);
    expect(state.textEditingValue.text, '13.8500');
  });
}
