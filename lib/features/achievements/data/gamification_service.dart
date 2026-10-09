import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/achievement_model.dart';
import '../../../models/budget_model.dart';
import '../../../core/constants/app_constants.dart';
import 'gamification_rules.dart';

/// An action is already saved before this result is requested. A failed reward
/// must never ask the user to register that financial action a second time.
class RewardResult {
  final bool confirmed;
  final int pointsAwarded;
  final int totalPoints;
  final int currentStreak;
  final Object? error;
  const RewardResult({
    required this.confirmed,
    this.pointsAwarded = 0,
    this.totalPoints = 0,
    this.currentStreak = 0,
    this.error,
  });
}

class GamificationService {
  final FirebaseFirestore _db;
  final DateTime Function() _now;
  GamificationService({FirebaseFirestore? firestore, DateTime Function()? now})
    : _db = firestore ?? FirebaseFirestore.instance,
      _now = now ?? DateTime.now;

  /// Confirms only the action reward. Achievement scans are a separate step,
  /// allowing the UI to show these points without waiting for monthly queries.
  Future<RewardResult> onTransactionRegistered(
    String userId, {
    required bool isExpense,
  }) => _reward(
    userId,
    isExpense
        ? AppConstants.pointsPerExpenseRegistered
        : AppConstants.pointsPerIncomeRegistered,
    updateStreak: true,
  );

  Future<RewardResult> rewardAction(
    String userId,
    String action, {
    String? month,
  }) {
    if (action == 'budget_set') {
      if (month == null ||
          !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
        return Future.value(
          RewardResult(
            confirmed: false,
            error: ArgumentError('A budget reward requires its YYYY-MM month'),
          ),
        );
      }
      return _reward(userId, 25, budgetMonth: month);
    }
    final points = switch (action) {
      'expense_registered' => AppConstants.pointsPerExpenseRegistered,
      'income_registered' => AppConstants.pointsPerIncomeRegistered,
      'budget_complied' => AppConstants.pointsPerBudgetCompliance,
      _ => 0,
    };
    return _reward(userId, points);
  }

  /// One bonus for the first visit on a local calendar date. Visiting does not
  /// extend the streak that requires a registered financial transaction.
  Future<RewardResult> rewardDailyVisit(String userId) =>
      _reward(userId, 10, dailyVisit: true);

  Future<RewardResult> _reward(
    String userId,
    int points, {
    bool updateStreak = false,
    String? budgetMonth,
    bool dailyVisit = false,
  }) async {
    final now = _now();
    try {
      return await _db.runTransaction((tx) async {
        final reference = _db.collection('users').doc(userId);
        final snapshot = await tx.get(reference);
        if (!snapshot.exists) throw StateError('User does not exist');
        final data = snapshot.data()!;
        final months = List<String>.from(
          data['rewardedBudgetMonths'] ?? const [],
        );
        final today = GamificationRules.dayKey(now);
        final dailyDate = data['lastDailyRewardDate'] as String?;
        // Dates sort chronologically. An older device clock cannot move this
        // marker backwards and earn another bonus for a previously visited day.
        final dailyAlreadyAwarded =
            dailyVisit && dailyDate != null && dailyDate.compareTo(today) >= 0;
        final awarded =
            dailyAlreadyAwarded ||
                (budgetMonth != null && months.contains(budgetMonth))
            ? 0
            : points;
        final total = ((data['points'] ?? 0) as num).toInt() + awarded;
        var streak = ((data['currentStreak'] ?? 0) as num).toInt();
        final updates = <String, dynamic>{
          'points': total,
          'level': GamificationRules.levelName(total),
        };
        if (updateStreak) {
          final lastDate = data['lastTxDate'] as String?;
          if (lastDate != today) {
            streak = GamificationRules.activeStreak(streak, lastDate, now) + 1;
          }
          updates.addAll({'currentStreak': streak, 'lastTxDate': today});
        }
        if (budgetMonth != null && awarded > 0) {
          updates['rewardedBudgetMonths'] = [...months, budgetMonth];
        }
        if (dailyVisit && awarded > 0) {
          updates['lastDailyRewardDate'] = today;
        }
        tx.update(reference, updates);
        return RewardResult(
          confirmed: true,
          pointsAwarded: awarded,
          totalPoints: total,
          currentStreak: streak,
        );
      });
    } catch (error) {
      return RewardResult(confirmed: false, error: error);
    }
  }

  /// Errors propagate: unavailable data cannot safely be treated as zero spent.
  Future<List<Achievement>> checkAndUnlockAchievements(String userId) async {
    final now = _now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final previous = DateTime(now.year, now.month - 1);
    final previousMonth =
        '${previous.year}-${previous.month.toString().padLeft(2, '0')}';
    final existing = await getUserAchievements(userId);
    final user = (await _db.collection('users').doc(userId).get()).data();
    if (user == null) throw StateError('User does not exist');
    final expenses = await _records('expenses', userId, month: month);
    final incomes = await _records('incomes', userId, month: month);
    final budgets = await _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .get();
    final previousBudget = Budget.latestForMonth(
      budgets.docs.map((doc) => Budget.fromMap(doc.data(), doc.id)),
      previousMonth,
    );
    final previousExpenses = previousBudget == null
        ? <Map<String, dynamic>>[]
        : await _records('expenses', userId, month: previousMonth);
    // Historical existence is bounded to one record per collection. It repairs
    // first-transaction eligibility even if the current month has no activity.
    final needsFirst = !existing.any(
      (a) => a.title == 'Primera transacción' && a.isUnlocked,
    );
    var anyTransaction = expenses.isNotEmpty || incomes.isNotEmpty;
    if (needsFirst && !anyTransaction) {
      anyTransaction =
          (await _db
                  .collection('expenses')
                  .where('userId', isEqualTo: userId)
                  .limit(1)
                  .get())
              .docs
              .isNotEmpty;
      if (!anyTransaction) {
        anyTransaction =
            (await _db
                    .collection('incomes')
                    .where('userId', isEqualTo: userId)
                    .limit(1)
                    .get())
                .docs
                .isNotEmpty;
      }
    }
    double sum(List<Map<String, dynamic>> records) => records.fold(
      0.0,
      (total, record) => total + ((record['amount'] ?? 0) as num).toDouble(),
    );
    final unlocked = <Achievement>[];
    for (final template in AchievementTemplates.templates) {
      final key = template['key'] as String;
      final title = template['title'] as String;
      if (existing.any((a) => a.title == title && a.isUnlocked)) continue;
      final progress = GamificationRules.achievementProgress(
        key,
        currentStreak: GamificationRules.activeStreak(
          ((user['currentStreak'] ?? 0) as num).toInt(),
          user['lastTxDate'] as String?,
          now,
        ),
        expenseCount: expenses.length,
        incomeCount: incomes.length,
        totalExpenses: sum(expenses),
        totalIncomes: sum(incomes),
        impulsiveExpenses: sum(
          expenses.where((e) => e['isImpulsive'] == true).toList(),
        ),
        hasPreviousBudget: previousBudget != null,
        previousExpenses: sum(previousExpenses),
        previousBudgetLimit: previousBudget?.monthlyLimit ?? 0,
        hasAnyTransaction: anyTransaction,
      );
      if (progress < 1) continue;
      final awarded = await _unlock(
        userId,
        template,
        existing.where((a) => a.title == title).toList(),
        now,
      );
      if (awarded != null) unlocked.add(awarded);
    }
    return unlocked;
  }

  Future<Achievement?> _unlock(
    String userId,
    Map<String, dynamic> template,
    List<Achievement> legacy,
    DateTime now,
  ) async {
    return _db.runTransaction((tx) async {
      final userRef = _db.collection('users').doc(userId);
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw StateError('User does not exist');
      final data = userSnap.data()!;
      final key = template['key'] as String;
      final rewarded = Map<String, dynamic>.from(
        data['rewardedAchievements'] ?? const {},
      );
      if (rewarded[key] == true) return null;
      // Only read existing documents returned by the owner query. Existing
      // rules deny reads of missing achievements; the user marker guards races.
      for (final achievement in legacy) {
        if (achievement.id == null) continue;
        final snapshot = await tx.get(
          _db.collection('achievements').doc(achievement.id),
        );
        if (snapshot.data()?['unlockedAt'] != null) return null;
      }
      final id = legacy.firstOrNull?.id ?? '${userId}_$key';
      final achievement = Achievement(
        id: id,
        userId: userId,
        title: template['title'] as String,
        description: template['description'] as String,
        icon: template['icon'] as String,
        points: template['points'] as int,
        category: template['category'] as String,
        type: key,
        unlockedAt: now,
      );
      final total = ((data['points'] ?? 0) as num).toInt() + achievement.points;
      tx.set(
        _db.collection('achievements').doc(id),
        achievement.toMap(),
        SetOptions(merge: true),
      );
      tx.update(userRef, {
        'points': total,
        'level': GamificationRules.levelName(total),
        'rewardedAchievements': {...rewarded, key: true},
      });
      return achievement;
    });
  }

  Future<List<Map<String, dynamic>>> _records(
    String collection,
    String userId, {
    required String month,
  }) async {
    final snapshot = await _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('month', isEqualTo: month)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Achievement>> getUserAchievements(String userId) async {
    final snapshot = await _db
        .collection('achievements')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => Achievement.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<Achievement>> watchUserAchievements(String userId) => _db
      .collection('achievements')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Achievement.fromMap(doc.data(), doc.id))
            .toList(),
      );

  int calculateLevel(int points) => GamificationRules.levelForPoints(points);
  int pointsForNextLevel(int currentLevel) =>
      GamificationRules.nextLevelThreshold(currentLevel);
  int pointsForCurrentLevel(int level) => GamificationRules.levelFloor(level);
  Future<Map<String, dynamic>> getUserProgress(String userId) async {
    final data = (await _db.collection('users').doc(userId).get()).data() ?? {};
    final points = ((data['points'] ?? 0) as num).toInt();
    final level = calculateLevel(points);
    return {
      'points': points,
      'level': GamificationRules.levelName(points),
      'numericLevel': level,
      'nextLevel': GamificationRules.levelName(pointsForNextLevel(level)),
      'pointsToNextLevel': pointsForNextLevel(level) - points,
    };
  }
}
