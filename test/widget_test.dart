import 'package:flutter_test/flutter_test.dart';

import 'package:financial_control/main.dart';

void main() {
  testWidgets('MyApp renders splash branding', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Chiroless'), findsOneWidget);
    expect(
      find.text('Eleva tus finanzas al siguiente nivel'),
      findsOneWidget,
    );
  });
}
