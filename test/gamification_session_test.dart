import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/features/achievements/presentation/widgets/gamification_session.dart';
import 'package:financial_control/features/achievements/data/gamification_service.dart';

void main() {
  testWidgets(
    'level reward waits behind an open form and celebrates after return',
    (tester) async {
      final points = ValueNotifier<int?>(140);
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(points.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: ValueListenableBuilder<int?>(
              valueListenable: points,
              builder: (context, value, _) => GamificationSession(
                points: value,
                onDailyVisit: () async => const RewardResult(confirmed: true),
                child: const Text('Saldo'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Registrar gasto')),
        ),
      );
      await tester.pumpAndSettle();
      points.value = 155;
      await tester.pumpAndSettle();
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.textContaining('¡Subiste'), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('¡Subiste al nivel 2!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'first loaded balance is silent, increases celebrate once and decreases stay silent',
    (tester) async {
      final points = ValueNotifier<int?>(null);
      addTearDown(points.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int?>(
              valueListenable: points,
              builder: (context, value, _) => GamificationSession(
                points: value,
                onDailyVisit: () async => const RewardResult(confirmed: true),
                child: const Text('Saldo'),
              ),
            ),
          ),
        ),
      );
      points.value = 140;
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('¡Subiste'), findsNothing);
      points.value = 510;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('¡Subiste al nivel 4!'), findsOneWidget);
      expect(find.text('Saldo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      points.value = 500;
      await tester.pumpAndSettle();
      expect(find.textContaining('¡Subiste'), findsNothing);
      points.value = 510;
      await tester.pumpAndSettle();
      expect(find.textContaining('¡Subiste'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'daily visit waits for loaded user and guards overlapping resumes',
    (tester) async {
      final points = ValueNotifier<int?>(null);
      addTearDown(points.dispose);
      final reward = Completer<RewardResult>();
      var visits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int?>(
              valueListenable: points,
              builder: (context, value, _) => GamificationSession(
                points: value,
                onDailyVisit: () {
                  visits++;
                  return reward.future;
                },
                child: const Text('Saldo'),
              ),
            ),
          ),
        ),
      );
      expect(visits, 0);
      points.value = 20;
      await tester.pump();
      await tester.pump();
      expect(visits, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(visits, 1);
      reward.complete(
        const RewardResult(confirmed: true, pointsAwarded: 10, totalPoints: 30),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Revisión diaria: +10 puntos'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
