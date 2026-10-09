import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/models/savings_leaderboard_model.dart';
import 'package:financial_control/features/achievements/data/savings_leaderboard_service.dart';
import 'package:financial_control/features/achievements/presentation/widgets/savings_leaderboard_sync.dart';
import 'package:financial_control/features/achievements/presentation/widgets/savings_leaderboard_panel.dart';
import 'support/memory_firestore.dart';

class LiveLeaderboard extends SavingsLeaderboardService {
  LiveLeaderboard() : super(firestore: MemoryFirestore());
  final participation = StreamController<SavingsParticipation>.broadcast();
  final incomes = StreamController<void>.broadcast();
  final expenses = StreamController<void>.broadcast();
  final entries = StreamController<List<SavingsEntry>>.broadcast();
  final List<String> synchronized = [];
  Completer<void>? participationGate;
  @override
  Future<void> participate(String userId, String alias) async {
    if (participationGate != null) {
      await participationGate!.future;
    } else {
      await super.participate(userId, alias);
    }
  }

  @override
  Stream<SavingsParticipation> watchParticipation(String userId) =>
      participation.stream;
  @override
  Stream<void> watchTransactions(
    String userId,
    String month, {
    required bool income,
  }) => income ? incomes.stream : expenses.stream;
  @override
  Stream<List<SavingsEntry>> watchMonth(String month) => entries.stream;
  @override
  Future<void> synchronizeMonth(
    String userId,
    String month, {
    bool Function()? isCurrent,
  }) async {
    synchronized.add(month);
  }

  Future<void> close() async {
    await participation.close();
    await incomes.close();
    await expenses.close();
    await entries.close();
  }
}

void main() {
  testWidgets('an old participation action cannot refresh a new account', (
    tester,
  ) async {
    final service = LiveLeaderboard()..participationGate = Completer<void>();
    Widget page(String uid) => MaterialApp(
      home: Scaffold(
        body: SavingsLeaderboardPanel(userId: uid, service: service),
      ),
    );
    await tester.pumpWidget(page('u'));
    service.participation.add(const SavingsParticipation());
    service.entries.add(const []);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pumpWidget(page('other'));
    service.participationGate!.complete();
    await tester.pump();
    expect(service.synchronized, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await service.close();
  });
  testWidgets(
    'ranking month label updates immediately before new snapshots arrive',
    (tester) async {
      final service = LiveLeaderboard();
      var now = DateTime(2026, 10, 31, 23, 59);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavingsLeaderboardPanel(
              userId: 'u',
              service: service,
              now: () => now,
            ),
          ),
        ),
      );
      service.participation.add(const SavingsParticipation());
      service.entries.add(const []);
      await tester.pump();
      expect(find.text('2026-10'), findsOneWidget);
      now = DateTime(2026, 11, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('2026-11'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets(
    'source failure pauses publication until a real snapshot recovers',
    (tester) async {
      final service = LiveLeaderboard();
      await tester.pumpWidget(
        MaterialApp(
          home: SavingsLeaderboardSync(
            userId: 'u',
            service: service,
            now: () => DateTime(2026, 10),
            child: const Scaffold(),
          ),
        ),
      );
      service.participation.add(
        const SavingsParticipation(enabled: true, alias: 'Ana'),
      );
      service.incomes.add(null);
      service.expenses.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized.length, 1);
      service.expenses.addError(StateError('offline'));
      service.incomes.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized.length, 1);
      service.expenses.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized.length, 2);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets(
    'month rollover waits for fresh monthly streams before publishing',
    (tester) async {
      final service = LiveLeaderboard();
      var now = DateTime(2026, 10, 31, 23, 59);
      await tester.pumpWidget(
        MaterialApp(
          home: SavingsLeaderboardSync(
            userId: 'u',
            service: service,
            now: () => now,
            child: const Scaffold(),
          ),
        ),
      );
      service.participation.add(
        const SavingsParticipation(enabled: true, alias: 'Ana'),
      );
      service.incomes.add(null);
      service.expenses.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized, ['2026-10']);
      now = DateTime(2026, 11, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(service.synchronized, ['2026-10']);
      service.participation.add(
        const SavingsParticipation(enabled: true, alias: 'Ana'),
      );
      service.incomes.add(null);
      service.expenses.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized, ['2026-10', '2026-11']);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets('pending debounce is canceled when participation is withdrawn', (
    tester,
  ) async {
    final service = LiveLeaderboard();
    await tester.pumpWidget(
      MaterialApp(
        home: SavingsLeaderboardSync(
          userId: 'u',
          service: service,
          child: const Scaffold(),
        ),
      ),
    );
    service.participation.add(
      const SavingsParticipation(enabled: true, alias: 'Ana'),
    );
    service.incomes.add(null);
    service.expenses.add(null);
    await tester.pump();
    service.participation.add(const SavingsParticipation(enabled: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.synchronized, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await service.close();
  });
  testWidgets(
    'optional participation starts with an empty alias and preserves ranking on error',
    (tester) async {
      final service = LiveLeaderboard();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavingsLeaderboardPanel(userId: 'u', service: service),
          ),
        ),
      );
      service.participation.add(const SavingsParticipation());
      service.entries.add(const [
        SavingsEntry(userId: 'b', alias: 'Beto', savingsPercent: 50),
      ]);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(find.text('Participar en Ahorradores'), findsOneWidget);
      service.entries.addError(StateError('offline'));
      await tester.pump();
      expect(find.text('50.00%'), findsWidgets);
      expect(find.textContaining('datos anteriores'), findsOneWidget);
      service.entries.add(const []);
      await tester.pump();
      expect(find.textContaining('datos anteriores'), findsNothing);
      expect(find.textContaining('Aún no hay participantes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets('podium and alias controls fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = LiveLeaderboard();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavingsLeaderboardPanel(userId: 'u', service: service),
        ),
      ),
    );
    service.participation.add(const SavingsParticipation());
    service.entries.add(const [
      SavingsEntry(
        userId: 'a',
        alias: 'Un alias bastante largo',
        savingsPercent: 90,
      ),
      SavingsEntry(userId: 'b', alias: 'Segundo alias', savingsPercent: 80),
      SavingsEntry(userId: 'c', alias: 'Tercer alias', savingsPercent: 70),
    ]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await service.close();
  });
  testWidgets(
    'sync waits for both sources and refreshes on transaction changes',
    (tester) async {
      final service = LiveLeaderboard();
      await tester.pumpWidget(
        MaterialApp(
          home: SavingsLeaderboardSync(
            userId: 'u',
            service: service,
            now: () => DateTime(2026, 10),
            child: const Scaffold(),
          ),
        ),
      );
      service.participation.add(
        const SavingsParticipation(enabled: true, alias: 'Ana'),
      );
      service.incomes.add(null);
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized, isEmpty);
      service.expenses.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized, ['2026-10']);
      service.expenses.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.synchronized, ['2026-10', '2026-10']);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets(
    'leaderboard shows podium personal position and recorded data label',
    (tester) async {
      final service = LiveLeaderboard();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavingsLeaderboardPanel(
              userId: 'u',
              service: service,
              now: () => DateTime(2026, 10),
            ),
          ),
        ),
      );
      service.participation.add(
        const SavingsParticipation(enabled: true, alias: 'Ana'),
      );
      service.entries.add(const [
        SavingsEntry(userId: 'u', alias: 'Ana', savingsPercent: 25),
        SavingsEntry(userId: 'b', alias: 'Beto', savingsPercent: -10),
      ]);
      await tester.pump();
      expect(find.text('Tu posición: 1'), findsOneWidget);
      expect(find.text('25.00%'), findsWidgets);
      expect(find.text('Basado en movimientos registrados'), findsOneWidget);
      expect(find.text('-10.00%'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
}
