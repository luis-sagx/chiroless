import 'package:financial_control/features/transactions/data/transaction_service.dart';
import 'package:financial_control/features/budget/data/budget_service.dart';
import 'package:financial_control/models/budget_model.dart';
import 'package:financial_control/models/expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'El presupuesto usa los gastos ya leídos y distingue un límite heredado',
    () {
      final budget = Budget(
        userId: 'u',
        monthlyLimit: 100,
        month: '2026-09',
        categoryLimits: {'Comida': 40},
      );
      final expenses = [
        Expense(
          userId: 'u',
          amount: 25,
          category: 'Comida',
          date: DateTime(2026, 10, 1),
          description: 'Almuerzo',
        ),
        Expense(
          userId: 'u',
          amount: 15,
          category: 'Otros',
          date: DateTime(2026, 10, 2),
          description: 'Otro',
        ),
      ];
      final status = BudgetService.calculateBudgetStatus(
        budget,
        expenses,
        '2026-10',
      );
      expect(status['hasBudget'], true);
      expect(status['isInherited'], true);
      expect(status['totalSpent'], 40);
      expect(status['remaining'], 60);
      expect(status['categoryStatus']['Comida']['spent'], 25);
      expect(BudgetService.calculateBudgetStatus(null, expenses, '2026-10'), {
        'hasBudget': false,
      });
    },
  );

  test('La tendencia reutiliza meses conocidos y conserva el orden', () async {
    final requested = <String>[];
    final now = DateTime(2026, 10, 6);
    final cached = <String, MonthTotals>{};

    Future<MonthTotals> fetch(String month) async {
      requested.add(month);
      return MonthTotals(month: month, income: 20, expense: 10);
    }

    final first = await TransactionService.loadLastMonthsTotals(
      now: now,
      months: 6,
      knownTotals: {
        '2026-10': const MonthTotals(month: '2026-10', income: 30, expense: 15),
      },
      fetch: fetch,
    );
    expect(requested, ['2026-05', '2026-06', '2026-07', '2026-08', '2026-09']);
    expect(first.map((month) => month.month), [
      '2026-05',
      '2026-06',
      '2026-07',
      '2026-08',
      '2026-09',
      '2026-10',
    ]);
    expect(first.last.income, 30);

    cached.addEntries(first.map((month) => MapEntry(month.month, month)));
    requested.clear();
    final shorter = await TransactionService.loadLastMonthsTotals(
      now: now,
      months: 3,
      knownTotals: cached,
      fetch: fetch,
    );
    expect(requested, isEmpty);
    expect(shorter.map((month) => month.month), [
      '2026-08',
      '2026-09',
      '2026-10',
    ]);

    requested.clear();
    final longer = await TransactionService.loadLastMonthsTotals(
      now: now,
      months: 12,
      knownTotals: cached,
      fetch: fetch,
    );
    expect(requested, [
      '2025-11',
      '2025-12',
      '2026-01',
      '2026-02',
      '2026-03',
      '2026-04',
    ]);
    expect(longer.length, 12);
  });

  test('La tendencia propaga errores de lectura', () async {
    await expectLater(
      TransactionService.loadLastMonthsTotals(
        now: DateTime(2026, 10, 6),
        months: 3,
        knownTotals: const {},
        fetch: (_) async => throw StateError('sin conexión'),
      ),
      throwsStateError,
    );
  });
}
