import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/features/achievements/presentation/widgets/compact_level_indicator.dart';

void main() {
  testWidgets(
    'compact indicator keeps one line at narrow widths and opens objectives',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 110,
                child: CompactLevelIndicator(
                  points: 100000,
                  onTap: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CompactLevelIndicator)).height,
        lessThanOrEqualTo(32),
      );
      await tester.tap(find.byType(CompactLevelIndicator));
      expect(opened, true);
      expect(tester.takeException(), isNull);
    },
  );
}
