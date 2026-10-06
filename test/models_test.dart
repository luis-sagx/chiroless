import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financial_control/core/constants/app_constants.dart';
import 'package:financial_control/core/constants/transaction_categories.dart';
import 'package:financial_control/core/theme/app_exceptions.dart';
import 'package:financial_control/features/transactions/data/transaction_draft.dart';
import 'package:financial_control/models/achievement_model.dart';
import 'package:financial_control/models/budget_model.dart';
import 'package:financial_control/models/expense_model.dart';
import 'package:financial_control/models/income_model.dart';
import 'package:financial_control/models/metrics_model.dart';
import 'package:financial_control/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 3, 5);

  group('Expense', () {
    test('month derivado, roundtrip y copyWith', () {
      final e = Expense(
        userId: 'u',
        amount: 10,
        category: 'Ropa',
        date: date,
        description: 'x',
        isImpulsive: true,
      );
      expect(e.month, '2026-03');
      final back = Expense.fromMap(e.toMap(), 'id1');
      expect(back.id, 'id1');
      expect(back.amount, 10.0);
      expect(back.date, date);
      expect(back.isImpulsive, isTrue);
      expect(e.copyWith(amount: 5).amount, 5);
      expect(e.copyWith().category, 'Ropa');
    });

    test('fromMap con defaults', () {
      final e = Expense.fromMap({'date': Timestamp.fromDate(date)}, 'i');
      expect(e.userId, '');
      expect(e.amount, 0.0);
      expect(e.month, '2026-03');
      expect(e.isImpulsive, isFalse);
    });

    test('mover un gasto a otro mes actualiza la clave mensual', () {
      final original = Expense(
        id: 'e',
        userId: 'u',
        amount: 10,
        category: 'Ropa',
        date: date,
        description: '',
      );
      final moved = original.copyWith(date: DateTime(2026, 4, 1));
      expect(moved.toMap()['month'], '2026-04');
    });
  });

  group('Income', () {
    test('roundtrip, description opcional y copyWith', () {
      final i = Income(userId: 'u', amount: 100, source: 'Salario', date: date);
      expect(i.toMap().containsKey('description'), isFalse);
      final back = Income.fromMap(i.copyWith(description: 'd').toMap(), 'id');
      expect(back.description, 'd');
      expect(back.month, '2026-03');
      expect(back.source, 'Salario');
    });

    test('fromMap con defaults', () {
      final i = Income.fromMap({'date': Timestamp.fromDate(date)}, 'i');
      expect(i.source, '');
      expect(i.amount, 0.0);
    });

    test('mover un ingreso a otro mes actualiza la clave mensual', () {
      final original = Income(
        id: 'i',
        userId: 'u',
        amount: 100,
        source: 'Salario',
        date: date,
      );
      final moved = original.copyWith(date: DateTime(2026, 4, 1));
      expect(moved.toMap()['month'], '2026-04');
    });
  });

  group('Budget', () {
    test('usa el último cambio anterior o igual al mes consultado', () {
      final january = Budget(userId: 'u', monthlyLimit: 500, month: '2026-01');
      final march = Budget(userId: 'u', monthlyLimit: 700, month: '2026-03');
      final future = Budget(userId: 'u', monthlyLimit: 900, month: '2026-11');
      final changes = [future, january, march];
      expect(Budget.latestForMonth(changes, '2025-12'), isNull);
      expect(Budget.latestForMonth(changes, '2026-02'), same(january));
      expect(Budget.latestForMonth(changes, '2026-03'), same(march));
      expect(Budget.latestForMonth(changes, '2026-09'), same(march));
      expect(Budget.latestForMonth(changes, '2026-11'), same(future));
    });

    test(
      'un límite heredado crea una nueva configuración desde el mes editado',
      () {
        final original = Budget(
          id: 'original',
          userId: 'u',
          monthlyLimit: 500,
          month: '2026-03',
          categoryLimits: {'Comida': 100},
        );
        final override = original.overrideFrom('2026-06', monthlyLimit: 600);
        expect(original.month, '2026-03');
        expect(original.monthlyLimit, 500);
        expect(override.id, isNull);
        expect(override.month, '2026-06');
        expect(override.monthlyLimit, 600);
        expect(override.categoryLimits, {'Comida': 100});
        expect(override.toMap()['month'], '2026-06');
      },
    );

    test('roundtrip con y sin categoryLimits', () {
      final b = Budget(userId: 'u', monthlyLimit: 500, month: '2026-03');
      expect(b.toMap().containsKey('categoryLimits'), isFalse);
      final b2 = Budget.fromMap(b.toMap(), 'id');
      expect(b2.categoryLimits, isNull);
      final c = b.copyWith(categoryLimits: {'Ropa': 50});
      final c2 = Budget.fromMap(c.toMap(), 'id');
      expect(c2.categoryLimits, {'Ropa': 50.0});
      expect(c2.monthlyLimit, 500.0);
      expect(b.copyWith(userId: 'z', monthlyLimit: 1, month: 'm').userId, 'z');
    });

    test('fromMap con defaults', () {
      final b = Budget.fromMap({'createdAt': Timestamp.fromDate(date)}, 'i');
      expect(b.userId, '');
      expect(b.month, '');
    });
  });

  group('FinancialMetrics', () {
    test('calculateControlScore', () {
      expect(
        FinancialMetrics.calculateControlScore(
          budgetCompliance: 100,
          impulsivePercentage: 0,
          savingsPercentage: 100,
          registrationFrequency: 30,
        ),
        100,
      );
      expect(
        FinancialMetrics.calculateControlScore(
          budgetCompliance: 0,
          impulsivePercentage: 100,
          savingsPercentage: 0,
          registrationFrequency: 0,
        ),
        0,
      );
      expect(
        FinancialMetrics.calculateControlScore(
          budgetCompliance: 50,
          impulsivePercentage: 50,
          savingsPercentage: 50,
          registrationFrequency: 15,
        ),
        50,
      );
      // fuera de rango se acota a 100
      expect(
        FinancialMetrics.calculateControlScore(
          budgetCompliance: 500,
          impulsivePercentage: 0,
          savingsPercentage: 500,
          registrationFrequency: 30,
        ),
        100,
      );
    });

    test('roundtrip, defaults y copyWith', () {
      final m = FinancialMetrics(
        userId: 'u',
        totalExpenses: 1,
        totalIncome: 2,
        savings: 1,
        impulsiveExpensesPercentage: 10,
        budgetCompliancePercentage: 90,
        controlScore: 70,
        period: 'post',
        month: '2026-03',
        calculatedAt: date,
      );
      final back = FinancialMetrics.fromMap(m.toMap(), 'id');
      expect(back.period, 'post');
      expect(back.controlScore, 70);
      expect(back.calculatedAt, date);
      expect(m.copyWith(controlScore: 1, period: 'pre').period, 'pre');
      expect(m.copyWith().totalIncome, 2.0);
      final d = FinancialMetrics.fromMap({
        'calculatedAt': Timestamp.fromDate(date),
      }, 'i');
      expect(d.period, 'pre');
      expect(d.totalExpenses, 0.0);
    });
  });

  group('Achievement', () {
    test('roundtrip bloqueado/desbloqueado y copyWith', () {
      final a = Achievement(
        userId: 'u',
        title: 't',
        description: 'd',
        icon: 'star',
        points: 10,
        category: 'streak',
      );
      expect(a.isUnlocked, isFalse);
      expect(a.toMap()['unlockedAt'], isNull);
      final u = a.copyWith(unlockedAt: date, type: 'x', points: 5);
      expect(u.isUnlocked, isTrue);
      final back = Achievement.fromMap(u.toMap(), 'id');
      expect(back.unlockedAt, date);
      expect(back.type, 'x');
      expect(Achievement.fromMap(a.toMap(), 'id').unlockedAt, isNull);
      final d = Achievement.fromMap({}, 'i');
      expect(d.icon, 'emoji_events');
      expect(d.category, 'milestone');
    });

    test('templates tienen claves únicas', () {
      final keys = AchievementTemplates.templates.map((t) => t['key']);
      expect(keys.toSet().length, keys.length);
    });
  });

  test('AppUser.toMap', () {
    final u = AppUser(
      uid: '1',
      name: 'n',
      email: 'e',
      level: 'Novato',
      createdAt: date,
    );
    expect(u.toMap()['points'], 0);
    expect(u.toMap()['name'], 'n');
  });

  group('TransactionCategories', () {
    test('lookup con fallback a Otros', () {
      expect(TransactionCategories.expenseInfo('Salud').name, 'Salud');
      expect(TransactionCategories.expenseInfo('nada').name, 'Otros');
      expect(TransactionCategories.incomeInfo('Beca').name, 'Beca');
      expect(TransactionCategories.incomeInfo('nada').name, 'Otros');
      expect(TransactionCategories.expenseNames, contains('Ropa'));
      expect(TransactionCategories.incomeNames, contains('Salario'));
    });
  });

  test('AppConstants coherentes', () {
    expect(
      AppConstants.warningBudgetPercentage <
          AppConstants.criticalBudgetPercentage,
      isTrue,
    );
    expect(AppConstants.userLevels, isNotEmpty);
  });

  group('TransactionDraft.isComplete', () {
    test('requiere monto > 0 y categoría', () {
      TransactionDraft d(double? a, String? c) =>
          TransactionDraft(isExpense: true, amount: a, category: c, date: date);
      expect(d(1, 'x').isComplete, isTrue);
      expect(d(0, 'x').isComplete, isFalse);
      expect(d(null, 'x').isComplete, isFalse);
      expect(d(1, null).isComplete, isFalse);
    });
  });

  group('AuthExceptionHandler', () {
    test('mapea códigos conocidos y desconocidos', () {
      const codes = [
        'invalid-email',
        'user-disabled',
        'user-not-found',
        'wrong-password',
        'email-already-in-use',
        'operation-not-allowed',
        'weak-password',
        'invalid-credential',
        'too-many-requests',
        'network-request-failed',
        'requires-recent-login',
      ];
      for (final c in codes) {
        final msg = AuthExceptionHandler.handleException(
          FirebaseAuthException(code: c),
        );
        expect(msg.startsWith('Error:'), isFalse, reason: c);
      }
      expect(
        AuthExceptionHandler.handleException(
          FirebaseAuthException(code: 'zzz', message: 'boom'),
        ),
        'Error: boom',
      );
      expect(
        AuthExceptionHandler.handleException(FirebaseAuthException(code: 'z')),
        'Error: Algo salió mal',
      );
      expect(
        AuthExceptionHandler.handleException(Exception('x')),
        'Error inesperado. Intenta de nuevo',
      );
      expect(AuthException('m', 'c').toString(), 'm');
    });
  });
}
