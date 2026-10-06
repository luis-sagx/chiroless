import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/budget_model.dart';
import '../../transactions/data/transaction_service.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransactionService _transactionService = TransactionService();

  /// Crear o actualizar presupuesto mensual
  Future<String?> setBudget(Budget budget) async {
    try {
      // Verificar si ya existe un presupuesto para ese mes
      final existing = await _db
          .collection('budgets')
          .where('userId', isEqualTo: budget.userId)
          .where('month', isEqualTo: budget.month)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Actualizar existente
        await _db
            .collection('budgets')
            .doc(existing.docs.first.id)
            .update(budget.toMap());
        return existing.docs.first.id;
      } else {
        // Crear nuevo
        final docRef = await _db.collection('budgets').add(budget.toMap());
        return docRef.id;
      }
    } catch (e) {
      print('Error estableciendo presupuesto: $e');
      return null;
    }
  }

  static String get currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Obtener el último límite configurado hasta el mes actual.
  Future<Budget?> getCurrentBudget(String userId) async {
    return getBudgetByMonth(userId, currentMonth);
  }

  /// Devuelve el último límite vigente sin crear documentos mensuales.
  Future<Budget?> getBudgetByMonth(String userId, String month) async {
    try {
      // Un usuario normalmente tiene pocos cambios de límite; esta consulta
      // de igualdad usa el índice de campo simple de Firestore.
      final snapshot = await _db
          .collection('budgets')
          .where('userId', isEqualTo: userId)
          .get();
      return Budget.latestForMonth(
        snapshot.docs.map((doc) => Budget.fromMap(doc.data(), doc.id)),
        month,
      );
    } catch (e) {
      print('Error obteniendo presupuesto: $e');
      return null;
    }
  }

  /// Obtener estado del presupuesto actual (cuánto se ha gastado vs límite)
  Future<Map<String, dynamic>> getBudgetStatus(String userId) async {
    try {
      final budget = await getCurrentBudget(userId);
      if (budget == null) {
        return {'hasBudget': false};
      }

      // El presupuesto puede venir de un mes anterior; el gasto es del actual.
      final expenses = await _transactionService.getUserExpenses(
        userId,
        month: currentMonth,
      );
      final totalSpent = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      final remaining = budget.monthlyLimit - totalSpent;
      final percentageUsed = (totalSpent / budget.monthlyLimit) * 100;

      // Estado del presupuesto
      String status = 'good'; // good, warning, critical, exceeded
      if (percentageUsed >= 100) {
        status = 'exceeded';
      } else if (percentageUsed >= 95) {
        status = 'critical';
      } else if (percentageUsed >= 80) {
        status = 'warning';
      }

      // Calcular status por categoría si existe
      Map<String, Map<String, dynamic>>? categoryStatus;
      if (budget.categoryLimits != null && budget.categoryLimits!.isNotEmpty) {
        categoryStatus = {};
        final expensesByCategory = <String, double>{};
        for (final expense in expenses) {
          expensesByCategory.update(
            expense.category,
            (total) => total + expense.amount,
            ifAbsent: () => expense.amount,
          );
        }

        for (var entry in budget.categoryLimits!.entries) {
          final category = entry.key;
          final limit = entry.value;
          final spent = expensesByCategory[category] ?? 0.0;
          final catRemaining = limit - spent;
          final catPercentage = (spent / limit) * 100;

          String catStatus = 'good';
          if (catPercentage >= 100) {
            catStatus = 'exceeded';
          } else if (catPercentage >= 95) {
            catStatus = 'critical';
          } else if (catPercentage >= 80) {
            catStatus = 'warning';
          }

          categoryStatus[category] = {
            'limit': limit,
            'spent': spent,
            'remaining': catRemaining,
            'percentage': catPercentage,
            'status': catStatus,
          };
        }
      }

      return {
        'hasBudget': true,
        'budget': budget,
        'isInherited': budget.month != currentMonth,
        'totalLimit': budget.monthlyLimit,
        'totalSpent': totalSpent,
        'remaining': remaining,
        'percentageUsed': percentageUsed,
        'status': status,
        'categoryStatus': categoryStatus,
      };
    } catch (e) {
      print('Error obteniendo estado del presupuesto: $e');
      return {'hasBudget': false, 'error': e.toString()};
    }
  }

  /// Stream del presupuesto actual en tiempo real
  Stream<Budget?> watchCurrentBudget(String userId) {
    final month = currentMonth;
    return _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return Budget.latestForMonth(
            snapshot.docs.map((doc) => Budget.fromMap(doc.data(), doc.id)),
            month,
          );
        });
  }

  /// Eliminar presupuesto
  Future<bool> deleteBudget(String budgetId) async {
    try {
      await _db.collection('budgets').doc(budgetId).delete();
      return true;
    } catch (e) {
      print('Error eliminando presupuesto: $e');
      return false;
    }
  }

  /// Verificar si se debe enviar alerta de presupuesto
  Future<Map<String, dynamic>?> checkBudgetAlert(String userId) async {
    try {
      final status = await getBudgetStatus(userId);

      if (!status['hasBudget']) return null;

      final percentageUsed = status['percentageUsed'] as double;

      // Alertas en 80%, 95%, y 100%
      if (percentageUsed >= 100) {
        return {
          'type': 'exceeded',
          'title': '¡Presupuesto excedido!',
          'message':
              'Has superado tu límite mensual de \$${status['totalLimit'].toStringAsFixed(2)}',
          'severity': 'critical',
        };
      } else if (percentageUsed >= 95) {
        return {
          'type': 'critical',
          'title': 'Alerta crítica',
          'message':
              'Has usado el ${percentageUsed.toStringAsFixed(1)}% de tu presupuesto',
          'severity': 'high',
        };
      } else if (percentageUsed >= 80) {
        return {
          'type': 'warning',
          'title': 'Advertencia',
          'message':
              'Has usado el ${percentageUsed.toStringAsFixed(1)}% de tu presupuesto',
          'severity': 'medium',
        };
      }

      return null;
    } catch (e) {
      print('Error verificando alertas: $e');
      return null;
    }
  }

  /// Obtener historial de presupuestos (últimos 6 meses)
  Future<List<Budget>> getBudgetHistory(String userId) async {
    try {
      final snapshot = await _db
          .collection('budgets')
          .where('userId', isEqualTo: userId)
          .orderBy('month', descending: true)
          .limit(6)
          .get();

      return snapshot.docs
          .map((doc) => Budget.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo historial: $e');
      return [];
    }
  }
}
