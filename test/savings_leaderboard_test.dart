import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/models/savings_leaderboard_model.dart';
import 'package:financial_control/features/achievements/data/savings_leaderboard_service.dart';
import 'support/memory_firestore.dart';

void main() {
  test('percentage rounds to the precision displayed in the table', () {
    expect(SavingsLeaderboardRules.percentage(300, 200), 33.33);
  });
  test(
    'an invalidated refresh cannot publish after its session ends',
    () async {
      final db = MemoryFirestore();
      db.documents['incomes/i'] = {
        'userId': 'u',
        'month': '2026-10',
        'amount': 100,
      };
      final service = SavingsLeaderboardService(firestore: db);
      await service.participate('u', 'Ana');
      await service.synchronizeMonth('u', '2026-10', isCurrent: () => false);
      expect(
        db.documents.containsKey('leaderboardMonths/2026-10/entries/u'),
        isFalse,
      );
    },
  );
  test(
    'withdrawal removes every published month and prevents future publishing',
    () async {
      final db = MemoryFirestore();
      final service = SavingsLeaderboardService(firestore: db);
      await service.participate('u', 'Ana');
      for (final month in ['2026-09', '2026-10']) {
        db.documents['incomes/$month'] = {
          'userId': 'u',
          'month': month,
          'amount': 100,
        };
        await service.synchronizeMonth('u', month);
      }
      await service.withdraw('u');
      await service.synchronizeMonth('u', '2026-10');
      expect(
        db.documents.keys.where((key) => key.startsWith('leaderboardMonths')),
        isEmpty,
      );
      expect(db.documents['users/u/leaderboard/profile']?['enabled'], isFalse);
      expect(
        db.documents['users/u/leaderboard/profile']?['publishedMonths'],
        isEmpty,
      );
    },
  );
  test(
    'removing income removes ranking entry rather than inventing a score',
    () async {
      final db = MemoryFirestore();
      final service = SavingsLeaderboardService(firestore: db);
      await service.participate('u', 'Ana');
      db.documents['incomes/i'] = {
        'userId': 'u',
        'month': '2026-10',
        'amount': 100,
      };
      await service.synchronizeMonth('u', '2026-10');
      db.documents.remove('incomes/i');
      await service.synchronizeMonth('u', '2026-10');
      expect(
        db.documents.containsKey('leaderboardMonths/2026-10/entries/u'),
        isFalse,
      );
    },
  );
  test(
    'failed withdrawal rolls back preference and published entry together',
    () async {
      final db = MemoryFirestore();
      final service = SavingsLeaderboardService(firestore: db);
      await service.participate('u', 'Ana');
      db.documents['incomes/i'] = {
        'userId': 'u',
        'month': '2026-10',
        'amount': 100,
      };
      await service.synchronizeMonth('u', '2026-10');
      db.failCommit = true;
      await expectLater(service.withdraw('u'), throwsStateError);
      expect(db.documents['users/u/leaderboard/profile']?['enabled'], isTrue);
      expect(
        db.documents.containsKey('leaderboardMonths/2026-10/entries/u'),
        isTrue,
      );
    },
  );
  test(
    'simultaneous publication and withdrawal leave no public entries',
    () async {
      final db = MemoryFirestore();
      final service = SavingsLeaderboardService(firestore: db);
      await service.participate('u', 'Ana');
      db.documents['incomes/i'] = {
        'userId': 'u',
        'month': '2026-10',
        'amount': 100,
      };
      await Future.wait([
        service.synchronizeMonth('u', '2026-10'),
        service.withdraw('u'),
      ]);
      expect(
        db.documents.keys.where((key) => key.startsWith('leaderboardMonths')),
        isEmpty,
      );
    },
  );
  test('monthly percentage excludes initial balance and keeps losses', () {
    expect(SavingsLeaderboardRules.percentage(1000, 750), 25);
    expect(SavingsLeaderboardRules.percentage(100, 150), -50);
    expect(SavingsLeaderboardRules.percentage(0, 20), isNull);
    expect(SavingsLeaderboardRules.percentage(double.infinity, 0), isNull);
  });
  test('ties share competition rank with deterministic alias order', () {
    const values = [
      SavingsEntry(userId: 'z', alias: 'Zeta', savingsPercent: 25),
      SavingsEntry(userId: 'a', alias: 'Ana', savingsPercent: 25),
      SavingsEntry(userId: 'b', alias: 'Beto', savingsPercent: -10),
    ];
    final sorted = SavingsLeaderboardRules.ordered(values);
    expect(sorted.map((e) => e.userId), ['a', 'z', 'b']);
    expect(SavingsLeaderboardRules.rankOf(sorted, 'z'), 1);
    expect(SavingsLeaderboardRules.rankOf(sorted, 'b'), 3);
  });
  test(
    'participation projects alias and percentage without private amounts',
    () async {
      final db = MemoryFirestore();
      db.documents['incomes/i'] = {
        'userId': 'u',
        'month': '2026-10',
        'amount': 1000,
      };
      db.documents['expenses/e'] = {
        'userId': 'u',
        'month': '2026-10',
        'amount': 750,
      };
      final service = SavingsLeaderboardService(firestore: db);
      await service.participate('u', '  Colibri  ');
      await service.synchronizeMonth('u', '2026-10');
      final entry = db.documents['leaderboardMonths/2026-10/entries/u'];
      expect(entry?['savingsPercent'], 25);
      expect(entry?['alias'], 'Colibri');
      expect(entry?.keys.toSet(), {'alias', 'savingsPercent', 'updatedAt'});
    },
  );
}
