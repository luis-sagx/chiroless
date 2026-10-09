import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financial_control/features/achievements/data/gamification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/memory_firestore.dart';

void main() {
  late MemoryFirestore db;
  late GamificationService service;
  setUp(() {
    db = MemoryFirestore();
    db.documents['users/u'] = {
      'points': 140,
      'currentStreak': 3,
      'lastTxDate': '2026-10-07',
    };
    service = GamificationService(
      firestore: db,
      now: () => DateTime(2026, 10, 8),
    );
  });
  test(
    'Confirmed action atomically advances points, level and daily streak',
    () async {
      final dynamic result = await service.onTransactionRegistered(
        'u',
        isExpense: true,
      );
      expect(
        result,
        isNotNull,
        reason: 'A saved action must return its confirmed reward',
      );
      expect(result.confirmed, true);
      expect(result.pointsAwarded, 10);
      expect(result.totalPoints, 150);
      expect(result.currentStreak, 4);
      expect(db.documents['users/u']!['level'], 'Novato');
      await service.onTransactionRegistered('u', isExpense: false);
      expect(db.documents['users/u']!['points'], 165);
      expect(db.documents['users/u']!['currentStreak'], 4);
    },
  );
  test(
    'Failed action commit reports unconfirmed with no partial streak write',
    () async {
      db.failCommit = true;
      final dynamic result = await service.onTransactionRegistered(
        'u',
        isExpense: true,
      );
      expect(result.confirmed, false);
      expect(result.pointsAwarded, 0);
      expect(result.error, isNotNull);
      expect(db.documents['users/u']!['points'], 140);
      expect(db.documents['users/u']!['currentStreak'], 3);
    },
  );
  test(
    'Budget edits and concurrent requests earn points once per month',
    () async {
      final results = await Future.wait<dynamic>(
        List.generate(
          2,
          (_) => service.rewardAction('u', 'budget_set', month: '2026-10'),
        ),
      );
      expect(
        results
            .map((r) => r.pointsAwarded)
            .fold<int>(0, (a, b) => a + (b as int)),
        25,
      );
      expect(db.documents['users/u']!['points'], 165);
      await service.rewardAction('u', 'budget_set', month: '2026-11');
      expect(db.documents['users/u']!['points'], 190);
    },
  );
  test(
    'Concurrent achievement scans award first transaction only once',
    () async {
      db.documents['expenses/old'] = {'userId': 'u', 'month': '2025-01'};
      final results = await Future.wait<dynamic>(
        List.generate(2, (_) => service.checkAndUnlockAchievements('u')),
      );
      expect(results.expand((r) => r).length, 1);
      expect(db.documents['users/u']!['points'], 150);
      expect(
        db.documents['achievements/u_first_transaction']!['unlockedAt'],
        isA<Timestamp>(),
      );
    },
  );
  test(
    'A failed unlock preserves legacy pending achievement and points',
    () async {
      db.documents['expenses/old'] = {'userId': 'u', 'month': '2025-01'};
      db.documents['achievements/legacy'] = {
        'userId': 'u',
        'title': 'Primera transacción',
        'unlockedAt': null,
      };
      db.failCommit = true;
      await expectLater(
        service.checkAndUnlockAchievements('u'),
        throwsStateError,
      );
      expect(db.documents['achievements/legacy']!['unlockedAt'], null);
      expect(db.documents['users/u']!['points'], 140);
    },
  );
  test('Unlocked legacy achievement does not award duplicate points', () async {
    db.documents['expenses/old'] = {'userId': 'u', 'month': '2025-01'};
    db.documents['achievements/legacy'] = {
      'userId': 'u',
      'title': 'Primera transacción',
      'unlockedAt': Timestamp.fromDate(DateTime(2025)),
    };
    expect(await service.checkAndUnlockAchievements('u'), isEmpty);
    expect(db.documents['users/u']!['points'], 140);
  });
  test('A carried budget rewards compliance in the previous month', () async {
    db.documents['budgets/old'] = {
      'userId': 'u',
      'month': '2026-08',
      'monthlyLimit': 100,
      'createdAt': Timestamp.fromDate(DateTime(2026, 8)),
    };
    db.documents['budgets/future'] = {
      'userId': 'u',
      'month': '2026-11',
      'monthlyLimit': 1,
      'createdAt': Timestamp.fromDate(DateTime(2026, 11)),
    };
    db.documents['expenses/previous'] = {
      'userId': 'u',
      'month': '2026-09',
      'amount': 100,
    };
    final unlocked = await service.checkAndUnlockAchievements('u');
    expect(unlocked.any((a) => a.title == 'Presupuesto cumplido'), true);
    expect(db.documents['users/u']!['points'], 250);
  });
  test('A future budget never makes the previous month compliant', () async {
    db.documents['budgets/future'] = {
      'userId': 'u',
      'month': '2026-11',
      'monthlyLimit': 100,
      'createdAt': Timestamp.fromDate(DateTime(2026, 11)),
    };
    final unlocked = await service.checkAndUnlockAchievements('u');
    expect(unlocked.any((a) => a.title == 'Presupuesto cumplido'), false);
    expect(db.documents['users/u']!['points'], 140);
  });
  test(
    'First daily visit credits ten points without extending financial streak',
    () async {
      final result = await service.rewardDailyVisit('u');
      expect(result.confirmed, true);
      expect(result.pointsAwarded, 10);
      expect(result.totalPoints, 150);
      expect(db.documents['users/u']!['lastDailyRewardDate'], '2026-10-08');
      expect(db.documents['users/u']!['currentStreak'], 3);
      expect(db.documents['users/u']!['lastTxDate'], '2026-10-07');
    },
  );
  test(
    'Concurrent daily visits credit once and the next date credits again',
    () async {
      final results = await Future.wait([
        service.rewardDailyVisit('u'),
        service.rewardDailyVisit('u'),
      ]);
      expect(results.map((r) => r.pointsAwarded).toList()..sort(), [0, 10]);
      expect(db.documents['users/u']!['points'], 150);
      final tomorrow = GamificationService(
        firestore: db,
        now: () => DateTime(2026, 10, 9),
      );
      expect((await tomorrow.rewardDailyVisit('u')).pointsAwarded, 10);
      expect(db.documents['users/u']!['points'], 160);
      expect((await service.rewardDailyVisit('u')).pointsAwarded, 0);
      expect(db.documents['users/u']!['lastDailyRewardDate'], '2026-10-09');
    },
  );
  test(
    'Failed daily reward rolls back its date and permits a later retry',
    () async {
      db.failCommit = true;
      expect((await service.rewardDailyVisit('u')).confirmed, false);
      expect(db.documents['users/u']!['lastDailyRewardDate'], isNull);
      expect(db.documents['users/u']!['points'], 140);
      db.failCommit = false;
      expect((await service.rewardDailyVisit('u')).pointsAwarded, 10);
    },
  );
  test('User progress reports a next level after level six', () async {
    db.documents['users/u']!['points'] = 1250;
    final progress = await service.getUserProgress('u');
    expect(progress['numericLevel'], 7);
    expect(progress['pointsToNextLevel'], 250);
    expect(progress['nextLevel'], 'Maestro Financiero');
  });
}
