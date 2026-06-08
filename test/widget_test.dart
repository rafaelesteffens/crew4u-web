import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:crewpay_web/main.dart';

void main() {
  testWidgets('Crew 4U app starts', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CrewForYouApp());

    expect(find.text('Escala'), findsWidgets);
  });
}
