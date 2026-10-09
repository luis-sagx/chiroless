import 'package:financial_control/features/achievements/data/gamification_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Level progress resets at each threshold including extended levels', () {
    expect(GamificationRules.levelForPoints(149), 1);
    expect(GamificationRules.levelForPoints(150), 2);
    expect(GamificationRules.levelProgress(150), 0);
    expect(GamificationRules.levelProgress(225), .5);
    expect(GamificationRules.levelProgress(1200), .8);
    expect(GamificationRules.levelName(1000), 'Maestro Financiero');
    expect(GamificationRules.levelForPoints(1000), 6);
    expect(GamificationRules.levelForPoints(1249), 6);
    expect(GamificationRules.levelForPoints(1250), 7);
    expect(GamificationRules.levelForPoints(3500), 16);
    expect(GamificationRules.levelFloor(16), 3500);
    expect(GamificationRules.nextLevelThreshold(16), 3750);
    expect(GamificationRules.levelProgress(1250), 0);
    expect(GamificationRules.levelForPoints(-10), 1);
    expect(GamificationRules.levelProgress(-10), 0);
  });
  test(
    'Streak expires after skipped calendar day but yesterday remains active',
    () {
      expect(
        GamificationRules.activeStreak(7, '2026-10-07', DateTime(2026, 10, 8)),
        7,
      );
      expect(
        GamificationRules.activeStreak(7, '2026-10-06', DateTime(2026, 10, 8)),
        0,
      );
    },
  );
  test(
    'Savings needs income and five expenses and impulse limit is strict',
    () {
      expect(
        GamificationRules.achievementProgress(
          'savings_10',
          incomeCount: 1,
          totalIncomes: 100,
          totalExpenses: 85,
          expenseCount: 4,
        ),
        .8,
      );
      expect(
        GamificationRules.achievementProgress(
          'savings_10',
          incomeCount: 1,
          totalIncomes: 100,
          totalExpenses: 90,
          expenseCount: 5,
        ),
        1,
      );
      expect(
        GamificationRules.achievementProgress('savings_10', expenseCount: 5),
        0,
      );
      expect(
        GamificationRules.achievementProgress(
          'control_impulse',
          expenseCount: 10,
          totalExpenses: 100,
          impulsiveExpenses: 20,
        ),
        lessThan(1),
      );
      expect(
        GamificationRules.achievementProgress(
          'control_impulse',
          expenseCount: 10,
          totalExpenses: 100,
          impulsiveExpenses: 19,
        ),
        1,
      );
    },
  );
  test(
    'Budget completion needs a previous month budget, not just zero spending',
    () {
      expect(GamificationRules.achievementProgress('budget_month'), 0);
      expect(
        GamificationRules.achievementProgress(
          'budget_month',
          hasPreviousBudget: true,
          previousExpenses: 100,
          previousBudgetLimit: 100,
        ),
        1,
      );
      expect(
        GamificationRules.achievementProgress(
          'budget_month',
          hasPreviousBudget: true,
          previousExpenses: 101,
          previousBudgetLimit: 100,
        ),
        0,
      );
    },
  );
}
