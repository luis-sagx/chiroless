import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/features/achievements/presentation/pages/achievements_page.dart';
import 'package:financial_control/models/user_model.dart';
import 'package:financial_control/models/achievement_model.dart';
import 'package:financial_control/models/expense_model.dart';
import 'package:financial_control/models/income_model.dart';

void main() {
  testWidgets(
    'completed streak changes next action and stream errors preserve points',
    (tester) async {
      final users = StreamController<AppUser?>();
      final achievements = StreamController<List<Achievement>>();
      addTearDown(users.close);
      addTearDown(achievements.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementsPage(
              userStream: users.stream,
              achievementsStream: achievements.stream,
              expensesStream: Stream.value(<Expense>[]),
              incomesStream: Stream.value(<Income>[]),
            ),
          ),
        ),
      );
      users.add(
        AppUser(
          uid: 'u',
          name: 'Ana',
          email: '',
          level: '',
          points: 160,
          currentStreak: 1,
          lastTxDate: DateTime.now().toIso8601String().substring(0, 10),
          createdAt: DateTime(2026),
        ),
      );
      achievements.add([
        Achievement(
          userId: 'u',
          title: 'Primera transacción',
          description: '',
          icon: 'star',
          points: 10,
          category: 'milestone',
          unlockedAt: DateTime(2026),
        ),
        Achievement(
          userId: 'u',
          title: 'Racha de 7 días',
          description: '',
          icon: 'local_fire_department',
          points: 50,
          category: 'streak',
          unlockedAt: DateTime(2026),
        ),
      ]);
      await tester.pump();
      expect(find.textContaining('Configura un presupuesto'), findsOneWidget);
      users.addError(StateError('offline'));
      await tester.pump();
      expect(find.text('160 pts'), findsOneWidget);
      expect(find.textContaining('datos anteriores'), findsOneWidget);
      users.add(
        AppUser(
          uid: 'u',
          name: 'Ana',
          email: '',
          level: '',
          points: 175,
          createdAt: DateTime(2026),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('175 pts'), findsOneWidget);
      expect(find.textContaining('datos anteriores'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(users.hasListener, isFalse);
      expect(achievements.hasListener, isFalse);
    },
  );
}
