import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/expense_model.dart';
import '../../../models/income_model.dart';
import 'recurring_transaction_service.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========== EXPENSES ==========

  /// Crear un nuevo gasto
  Future<String?> createExpense(Expense expense) async {
    try {
      final docRef = await _db.collection('expenses').add(expense.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creando gasto: $e');
      return null;
    }
  }

  /// Obtener gastos del mes actual del usuario
  Future<List<Expense>> getUserExpenses(
    String userId, {
    String? month,
    bool rethrowOnError = false,
  }) async {
    try {
      final targetMonth =
          month ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

      final snapshot = await _db
          .collection('expenses')
          .where('userId', isEqualTo: userId)
          .where('month', isEqualTo: targetMonth)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Expense.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo gastos: $e');
      if (rethrowOnError) rethrow;
      return [];
    }
  }

  /// Obtener gastos por categoría
  Future<Map<String, double>> getExpensesByCategory(
    String userId, {
    String? month,
  }) async {
    try {
      final expenses = await getUserExpenses(userId, month: month);
      final Map<String, double> categoryTotals = {};

      for (var expense in expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      return categoryTotals;
    } catch (e) {
      print('Error calculando gastos por categoría: $e');
      return {};
    }
  }

  /// Actualizar un gasto
  Future<bool> updateExpense(Expense expense) async {
    try {
      if (expense.id == null) return false;

      await _db.collection('expenses').doc(expense.id).update(expense.toMap());
      return true;
    } catch (e) {
      print('Error actualizando gasto: $e');
      return false;
    }
  }

  /// Eliminar un gasto
  Future<bool> deleteExpense(String expenseId) async {
    try {
      final reference = _db.collection('expenses').doc(expenseId);
      final snapshot = await reference.get();
      final data = snapshot.data();
      final recurrenceId = data?['recurrenceId'] as String?;
      final recurrenceDate = data?['recurrenceDate'] as String?;
      if (recurrenceId != null && recurrenceDate != null) {
        await RecurringTransactionService().skipOccurrence(
          seriesId: recurrenceId,
          occurrenceDate: recurrenceDate,
        );
      }
      await reference.delete();
      return true;
    } catch (e) {
      print('Error eliminando gasto: $e');
      return false;
    }
  }

  /// Stream de gastos en tiempo real
  Stream<List<Expense>> watchUserExpenses(String userId, {String? month}) {
    final targetMonth =
        month ??
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    return _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('month', isEqualTo: targetMonth)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Expense.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // ========== INCOMES ==========

  /// Crear un nuevo ingreso
  Future<String?> createIncome(Income income) async {
    try {
      final docRef = await _db.collection('incomes').add(income.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creando ingreso: $e');
      return null;
    }
  }

  /// Obtener ingresos del mes actual del usuario
  Future<List<Income>> getUserIncomes(
    String userId, {
    String? month,
    bool rethrowOnError = false,
  }) async {
    try {
      final targetMonth =
          month ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

      final snapshot = await _db
          .collection('incomes')
          .where('userId', isEqualTo: userId)
          .where('month', isEqualTo: targetMonth)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Income.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo ingresos: $e');
      if (rethrowOnError) rethrow;
      return [];
    }
  }

  /// Obtener ingresos por fuente
  Future<Map<String, double>> getIncomesBySource(
    String userId, {
    String? month,
  }) async {
    try {
      final incomes = await getUserIncomes(userId, month: month);
      final Map<String, double> sourceTotals = {};

      for (var income in incomes) {
        sourceTotals[income.source] =
            (sourceTotals[income.source] ?? 0) + income.amount;
      }

      return sourceTotals;
    } catch (e) {
      print('Error calculando ingresos por fuente: $e');
      return {};
    }
  }

  /// Actualizar un ingreso
  Future<bool> updateIncome(Income income) async {
    try {
      if (income.id == null) return false;

      await _db.collection('incomes').doc(income.id).update(income.toMap());
      return true;
    } catch (e) {
      print('Error actualizando ingreso: $e');
      return false;
    }
  }

  /// Eliminar un ingreso
  Future<bool> deleteIncome(String incomeId) async {
    try {
      final reference = _db.collection('incomes').doc(incomeId);
      final snapshot = await reference.get();
      final data = snapshot.data();
      final recurrenceId = data?['recurrenceId'] as String?;
      final recurrenceDate = data?['recurrenceDate'] as String?;
      if (recurrenceId != null && recurrenceDate != null) {
        await RecurringTransactionService().skipOccurrence(
          seriesId: recurrenceId,
          occurrenceDate: recurrenceDate,
        );
      }
      await reference.delete();
      return true;
    } catch (e) {
      print('Error eliminando ingreso: $e');
      return false;
    }
  }

  /// Stream de ingresos en tiempo real
  Stream<List<Income>> watchUserIncomes(String userId, {String? month}) {
    final targetMonth =
        month ??
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    return _db
        .collection('incomes')
        .where('userId', isEqualTo: userId)
        .where('month', isEqualTo: targetMonth)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Income.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // ========== ANALYTICS ==========

  /// Obtener resumen financiero del mes
  Future<Map<String, dynamic>> getMonthSummary(
    String userId, {
    String? month,
  }) async {
    try {
      final expenses = await getUserExpenses(userId, month: month);
      final incomes = await getUserIncomes(userId, month: month);

      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );
      final totalIncomes = incomes.fold<double>(
        0,
        (sum, income) => sum + income.amount,
      );

      final impulsiveExpenses = expenses.where((e) => e.isImpulsive).toList();
      final impulsiveTotal = impulsiveExpenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      // Gastos por categoría
      final Map<String, double> expensesByCategory = {};
      for (var expense in expenses) {
        expensesByCategory[expense.category] =
            (expensesByCategory[expense.category] ?? 0) + expense.amount;
      }

      return {
        'totalExpenses': totalExpenses,
        'totalIncomes': totalIncomes,
        'balance': totalIncomes - totalExpenses,
        'impulsiveExpenses': impulsiveTotal,
        'impulsivePercentage': totalExpenses > 0
            ? (impulsiveTotal / totalExpenses) * 100
            : 0.0,
        'expenseCount': expenses.length,
        'incomeCount': incomes.length,
        'expensesByCategory': expensesByCategory,
      };
    } catch (e) {
      print('Error obteniendo resumen: $e');
      return {};
    }
  }

  /// Totales de los últimos [months] meses (incluye el actual), del más
  /// antiguo al más reciente.
  /// Reutiliza totales ya cargados y consulta solo meses faltantes. Los errores
  /// de lectura se propagan para evitar mostrar un cero como dato real.
  Future<List<MonthTotals>> getLastMonthsTotals(
    String userId, {
    int months = 6,
    Map<String, MonthTotals> knownTotals = const {},
  }) async {
    return loadLastMonthsTotals(
      now: DateTime.now(),
      months: months,
      knownTotals: knownTotals,
      fetch: (key) async {
        final expensesFuture = getUserExpenses(
          userId,
          month: key,
          rethrowOnError: true,
        );
        final incomes = await getUserIncomes(
          userId,
          month: key,
          rethrowOnError: true,
        );
        final expenses = await expensesFuture;
        return MonthTotals(
          month: key,
          income: incomes.fold<double>(0, (s, i) => s + i.amount),
          expense: expenses.fold<double>(0, (s, e) => s + e.amount),
        );
      },
    );
  }

  /// Compone un rango acotado en orden cronológico sin volver a pedir meses
  /// conocidos. [fetch] debe propagar errores de lectura.
  static Future<List<MonthTotals>> loadLastMonthsTotals({
    required DateTime now,
    required int months,
    required Map<String, MonthTotals> knownTotals,
    required Future<MonthTotals> Function(String month) fetch,
  }) async {
    final keys = List.generate(months, (i) {
      final d = DateTime(now.year, now.month - (months - 1 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
    return Future.wait(
      keys.map((key) async {
        final cached = knownTotals[key];
        if (cached != null) return cached;
        return fetch(key);
      }),
    );
  }

  /// Obtener últimas transacciones (combinadas)
  Future<List<Map<String, dynamic>>> getRecentTransactions(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final expenses = await getUserExpenses(userId);
      final incomes = await getUserIncomes(userId);

      List<Map<String, dynamic>> transactions = [];

      for (var expense in expenses) {
        transactions.add({
          'type': 'expense',
          'data': expense,
          'date': expense.date,
        });
      }

      for (var income in incomes) {
        transactions.add({
          'type': 'income',
          'data': income,
          'date': income.date,
        });
      }

      // Ordenar por fecha descendente
      transactions.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      return transactions.take(limit).toList();
    } catch (e) {
      print('Error obteniendo transacciones recientes: $e');
      return [];
    }
  }
}

/// Totales de un mes. [month] con formato "YYYY-MM".
class MonthTotals {
  final String month;
  final double income;
  final double expense;

  const MonthTotals({
    required this.month,
    required this.income,
    required this.expense,
  });
}
