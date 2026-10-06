import 'package:flutter_test/flutter_test.dart';

import 'package:financial_control/features/home/presentation/pages/splash_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  testWidgets('Splash renders branding while authentication is pending', (
    WidgetTester tester,
  ) async {
    final pendingSession = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          gate: StartupGate(
            hasSession: () => pendingSession.future,
            hasSeenWelcome: () async => true,
            markWelcomeSeen: () async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chiroless'), findsOneWidget);
    expect(find.text('Eleva tus finanzas al siguiente nivel'), findsOneWidget);
  });
}
