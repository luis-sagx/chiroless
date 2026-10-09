import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';

/// Shared financial habit rules, used for unlocking and displayed progress.
class GamificationRules {
  static const _thresholds = [0, 150, 300, 500, 750, 1000];
  static int levelForPoints(int points) => points >= 1000
      ? 6 + (points - 1000) ~/ 250
      : math.max(
          1,
          _thresholds.lastIndexWhere((threshold) => points >= threshold) + 1,
        );
  static String levelName(int points) =>
      AppConstants.userLevels[(levelForPoints(points).clamp(1, 6)) - 1];
  static int levelFloor(int level) => level >= 6
      ? 1000 + (level - 6) * 250
      : _thresholds[math.max(1, level) - 1];
  static int nextLevelThreshold(int level) =>
      levelFloor(math.max(1, level) + 1);
  static double levelProgress(int points) {
    final level = levelForPoints(points);
    final floor = levelFloor(level);
    return ((points - floor) / (nextLevelThreshold(level) - floor)).clamp(0, 1);
  }

  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  static int activeStreak(int stored, String? lastTxDate, DateTime now) {
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return lastTxDate == dayKey(now) || lastTxDate == dayKey(yesterday)
        ? math.max(0, stored)
        : 0;
  }

  static double achievementProgress(
    String key, {
    int currentStreak = 0,
    int expenseCount = 0,
    int incomeCount = 0,
    double totalExpenses = 0,
    double totalIncomes = 0,
    double impulsiveExpenses = 0,
    bool hasPreviousBudget = false,
    double previousExpenses = 0,
    double previousBudgetLimit = 0,
    bool hasAnyTransaction = false,
  }) {
    switch (key) {
      case 'first_transaction':
        return hasAnyTransaction || expenseCount + incomeCount > 0 ? 1 : 0;
      case 'streak_7':
        return (currentStreak / 7).clamp(0, 1);
      case 'budget_month':
        return hasPreviousBudget && previousExpenses <= previousBudgetLimit
            ? 1
            : 0;
      case 'savings_10':
        if (totalIncomes <= 0 || incomeCount <= 0) return 0;
        final savings = ((totalIncomes - totalExpenses) / totalIncomes / .1)
            .clamp(0.0, 1.0);
        return math.min((expenseCount / 5).clamp(0.0, 1.0), savings);
      case 'control_impulse':
        final count = (expenseCount / 10).clamp(0.0, 1.0);
        final ratio = totalExpenses > 0 ? impulsiveExpenses / totalExpenses : 0;
        // The unlock requires strictly less than 20%; count alone cannot finish it.
        return ratio < .2 ? count : math.min(count, .9);
      default:
        return 0;
    }
  }
}
