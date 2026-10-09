import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/models/achievement_model.dart';
import 'package:financial_control/features/achievements/data/gamification_service.dart';
import 'package:financial_control/features/achievements/presentation/widgets/gamification_session.dart';
import 'package:financial_control/features/achievements/presentation/widgets/mission_celebrations.dart';
import 'package:financial_control/features/achievements/presentation/widgets/joyful_celebration.dart';
import 'package:financial_control/features/achievements/presentation/widgets/reward_feedback.dart';
import 'support/memory_firestore.dart';

Achievement mission(String id, {String userId = 'u'}) => Achievement(
  id: id,
  userId: userId,
  title: 'Ahorrador constante',
  description: '',
  icon: 'savings',
  points: 75,
  unlockedAt: DateTime(2026),
  category: 'savings',
);

void main() {
  testWidgets(
    'queued rewards wait for the user balance before showing level progress',
    (tester) async {
      final points = ValueNotifier<int?>(null);
      addTearDown(points.dispose);
      MissionCelebrations.instance.publish('loading-user', [
        mission('loading-mission', userId: 'loading-user'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int?>(
              valueListenable: points,
              builder: (_, value, _) => GamificationSession(
                userId: 'loading-user',
                points: value,
                onDailyVisit: () async => const RewardResult(confirmed: true),
                child: const Text('Saldo'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(JoyfulCelebration), findsNothing);
      points.value = 1350;
      await tester.pumpAndSettle();
      expect(find.text('Nivel 7 · 150 puntos para avanzar'), findsOneWidget);
    },
  );
  Future<void> settleReward(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Widget shell(
    String uid, {
    int points = 215,
    bool reducedMotion = false,
    double textScale = 1,
    Future<RewardResult> Function()? daily,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: GamificationSession(
          userId: uid,
          points: points,
          onDailyVisit:
              daily ?? () async => const RewardResult(confirmed: true),
          child: const Text('Saldo'),
        ),
      ),
    ),
  );

  testWidgets(
    'five missions remain readable and scroll on a small screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MissionCelebrations.instance.publish(
        'narrow-user',
        List.generate(
          5,
          (i) => mission(
            'narrow-$i',
            userId: 'narrow-user',
          ).copyWith(title: 'Misión completada número $i'),
        ),
      );
      await tester.pumpWidget(
        shell('narrow-user', points: 1350, textScale: 1.3),
      );
      await settleReward(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Nivel 7 · 150 puntos para avanzar'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Nivel 7 · 150 puntos para avanzar').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('a delayed daily result cannot replace newer stream progress', (
    tester,
  ) async {
    final points = ValueNotifier<int?>(140);
    final daily = Completer<RewardResult>();
    addTearDown(points.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int?>(
            valueListenable: points,
            builder: (_, value, _) => GamificationSession(
              userId: 'daily-late',
              points: value,
              onDailyVisit: () => daily.future,
              child: const Text('Saldo'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    points.value = 225;
    await tester.pump();
    await settleReward(tester);
    daily.complete(
      const RewardResult(confirmed: true, pointsAwarded: 10, totalPoints: 150),
    );
    await tester.pump();
    await settleReward(tester);
    expect(find.text('Nivel 2 · 75 puntos para avanzar'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
  });

  testWidgets('a delayed mission joins an already visible level celebration', (
    tester,
  ) async {
    final points = ValueNotifier<int?>(140);
    addTearDown(points.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int?>(
            valueListenable: points,
            builder: (_, value, _) => GamificationSession(
              userId: 'delayed-user',
              points: value,
              onDailyVisit: () async => const RewardResult(confirmed: true),
              child: const Text('Saldo'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    points.value = 150;
    await tester.pump();
    await settleReward(tester);
    expect(find.text('¡Subiste al nivel 2!'), findsOneWidget);
    MissionCelebrations.instance.publish('delayed-user', [
      mission('delayed-mission', userId: 'delayed-user'),
    ]);
    points.value = 225;
    await tester.pump();
    await settleReward(tester);
    expect(find.byType(JoyfulCelebration), findsOneWidget);
    expect(find.text('¡Misión completada!'), findsOneWidget);
    expect(find.text('¡Subiste al nivel 2!'), findsOneWidget);
    expect(find.text('+75 puntos'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
  });

  testWidgets(
    'switching users drops pending presentation and the old daily result',
    (tester) async {
      final uid = ValueNotifier<String>('old-session');
      final oldReward = Completer<RewardResult>();
      addTearDown(uid.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: uid,
              builder: (_, userId, _) => GamificationSession(
                userId: userId,
                points: 140,
                onDailyVisit: () => userId == 'old-session'
                    ? oldReward.future
                    : Future.value(const RewardResult(confirmed: true)),
                child: const Text('Saldo'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      MissionCelebrations.instance.publish('old-session', [
        mission('old-mission', userId: 'old-session'),
      ]);
      uid.value = 'new-session';
      await tester.pump();
      oldReward.complete(
        const RewardResult(
          confirmed: true,
          pointsAwarded: 10,
          totalPoints: 150,
        ),
      );
      await tester.pump();
      await settleReward(tester);
      expect(find.byType(JoyfulCelebration), findsNothing);
      expect(find.byType(DailyRewardBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late confirmed unlock is delivered when the shell mounts and never repeated',
    (tester) async {
      final db = MemoryFirestore();
      db.documents['users/helper'] = {'points': 140};
      db.documents['expenses/first'] = {
        'userId': 'helper',
        'month': '2026-10',
        'amount': 1,
      };
      await refreshAchievements(
        GamificationService(firestore: db, now: () => DateTime(2026, 10, 8)),
        'helper',
      );
      await tester.pumpWidget(shell('helper', points: 150));
      await settleReward(tester);
      expect(find.text('Primera transacción'), findsOneWidget);
      expect(find.text('+10 puntos'), findsOneWidget);
      expect(find.textContaining('¡Subiste'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      MissionCelebrations.instance.publish('helper', [
        Achievement(
          id: 'helper_first_transaction',
          userId: 'helper',
          title: 'Primera transacción',
          description: '',
          icon: 'star',
          points: 10,
          unlockedAt: DateTime(2026),
          category: 'milestone',
        ),
      ]);
      await settleReward(tester);
      expect(find.text('¡Misión completada!'), findsNothing);
    },
  );

  testWidgets(
    'pending missions stay behind a form and other users never receive them',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: GamificationSession(
              userId: 'form-user',
              points: 215,
              onDailyVisit: () async => const RewardResult(confirmed: true),
              child: const Text('Saldo'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Guardar movimiento')),
        ),
      );
      await tester.pumpAndSettle();
      MissionCelebrations.instance.publish('someone-else', [
        mission('wrong-owner', userId: 'someone-else'),
      ]);
      MissionCelebrations.instance.publish('form-user', [
        mission('form-mission', userId: 'form-user'),
      ]);
      await settleReward(tester);
      expect(find.text('¡Misión completada!'), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Ahorrador constante'), findsOneWidget);
      await tester.pumpWidget(shell('someone-new'));
      await settleReward(tester);
      expect(find.text('¡Misión completada!'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daily level increase combines its reward on one card', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(
        'daily-level',
        points: 140,
        daily: () async => const RewardResult(
          confirmed: true,
          pointsAwarded: 10,
          totalPoints: 150,
        ),
      ),
    );
    await tester.pump();
    await settleReward(tester);
    expect(find.text('¡Subiste al nivel 2!'), findsOneWidget);
    expect(find.text('+10 puntos'), findsOneWidget);
    expect(find.byType(JoyfulCelebration), findsOneWidget);
    expect(find.byType(DailyRewardBanner), findsNothing);
  });

  testWidgets(
    'reduced motion retains mission and high level progress without particles',
    (tester) async {
      MissionCelebrations.instance.publish('reduced-user', [
        mission('reduced-mission', userId: 'reduced-user'),
      ]);
      await tester.pumpWidget(
        shell('reduced-user', points: 1350, reducedMotion: true),
      );
      await settleReward(tester);
      expect(find.text('+75 puntos'), findsOneWidget);
      expect(find.text('Nivel 7 · 150 puntos para avanzar'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .4,
      );
      expect(find.byKey(const ValueKey('celebration-confetti')), findsNothing);
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('joyful-celebration')),
      );
      expect(
        (container.decoration as BoxDecoration).color,
        const Color(0xFFFFFBEE),
      );
    },
  );

  testWidgets('an unconfirmed daily reward never produces positive feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(
        'failed-daily',
        daily: () async => const RewardResult(
          confirmed: false,
          pointsAwarded: 10,
          totalPoints: 225,
        ),
      ),
    );
    await tester.pump();
    await settleReward(tester);
    expect(find.byType(JoyfulCelebration), findsNothing);
    expect(find.byType(DailyRewardBanner), findsNothing);
  });
  testWidgets(
    'confirmed mission has its name, points and progress on a festive surface',
    (tester) async {
      final points = ValueNotifier<int?>(140);
      addTearDown(points.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int?>(
              valueListenable: points,
              builder: (_, value, _) => GamificationSession(
                userId: 'u',
                points: value,
                onDailyVisit: () async => const RewardResult(confirmed: true),
                child: const Text('Saldo'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      MissionCelebrations.instance.publish('u', [mission('first')]);
      points.value = 215;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('¡Misión completada!'), findsOneWidget);
      expect(find.text('Ahorrador constante'), findsOneWidget);
      expect(find.text('+75 puntos'), findsOneWidget);
      expect(find.text('¡Subiste al nivel 2!'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const ValueKey('celebration-confetti')),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
