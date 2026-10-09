import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/models/user_model.dart';
import 'package:financial_control/features/achievements/presentation/widgets/personal_progress_card.dart';

AppUser user(int points, {int streak = 0, String? lastDate}) => AppUser(
  uid: 'u',
  name: 'Ana',
  email: '',
  level: 'old',
  points: points,
  currentStreak: streak,
  lastTxDate: lastDate,
  createdAt: DateTime(2026),
);
void main() {
  testWidgets('a new user event updates points and remaining level progress', (
    tester,
  ) async {
    final events = StreamController<AppUser>();
    addTearDown(events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamBuilder<AppUser>(
            stream: events.stream,
            builder: (context, snapshot) => snapshot.hasData
                ? PersonalProgressCard(user: snapshot.data!)
                : const SizedBox(),
          ),
        ),
      ),
    );
    events.add(user(140));
    await tester.pump();
    expect(find.text('140 pts'), findsOneWidget);
    expect(find.text('10 puntos para el siguiente nivel'), findsOneWidget);
    events.add(user(155));
    await tester.pump();
    await tester.pump();
    expect(find.text('155 pts'), findsOneWidget);
    expect(find.textContaining('145 puntos'), findsOneWidget);
  });
  testWidgets('level six still offers progress towards level seven', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PersonalProgressCard(user: user(1200))),
      ),
    );
    expect(find.text('50 puntos para el siguiente nivel'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .8,
    );
  });
  testWidgets('expired streak resets and card works on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalProgressCard(
            user: user(750, streak: 9, lastDate: '2026-10-01'),
            now: DateTime(2026, 10, 8),
          ),
        ),
      ),
    );
    expect(find.text('0 días de racha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
