import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/achievement_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../transactions/data/transaction_service.dart';
import '../../budget/data/budget_service.dart';

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();

  // ========== ACHIEVEMENTS ==========

  /// Verificar y desbloquear logros automáticamente
  Future<List<Achievement>> checkAndUnlockAchievements(String userId) async {
    try {
      final List<Achievement> unlockedAchievements = [];

      // Obtener TODOS los logros del usuario (desbloqueados y pendientes)
      final allAchievements = await getUserAchievements(userId);

      // Crear mapa: título -> logro existente
      final Map<String, Achievement> existingAchievementsMap = {};
      for (var achievement in allAchievements) {
        existingAchievementsMap[achievement.title] = achievement;
      }

      // Obtener datos necesarios
      final userSnap = await _db.collection('users').doc(userId).get();
      final userData = userSnap.data() ?? {};
      final currentStreak = (userData['currentStreak'] ?? 0) as int;
      final expenses = await _transactionService.getUserExpenses(userId);
      final incomes = await _transactionService.getUserIncomes(userId);

      // Verificar cada template
      for (var template in AchievementTemplates.templates) {
        final title = template['title'] as String;
        final existingAchievement = existingAchievementsMap[title];

        if (existingAchievement != null &&
            existingAchievement.unlockedAt == null &&
            existingAchievement.id != null) {
          await _db
              .collection('achievements')
              .doc(existingAchievement.id)
              .delete();
        }

        // Si ya está desbloqueado (tiene unlockedAt), skip
        if (existingAchievement != null &&
            existingAchievement.unlockedAt != null) {
          continue;
        }

        bool shouldUnlock = false;

        // Lógica de desbloqueo según categoría
        switch (template['category']) {
          case 'milestone':
            if (title == 'Primera transacción') {
              shouldUnlock = expenses.isNotEmpty || incomes.isNotEmpty;
            } else if (title == 'Control total') {
              final totalExpenses = expenses.fold<double>(
                0,
                (total, expense) => total + expense.amount,
              );
              final impulsiveExpenses = expenses
                  .where((e) => e.isImpulsive)
                  .fold<double>(0, (total, expense) => total + expense.amount);
              final impulsivePercentage = totalExpenses > 0
                  ? (impulsiveExpenses / totalExpenses) * 100
                  : 0;
              shouldUnlock = expenses.length >= 10 && impulsivePercentage < 20;
            }
            break;

          case 'streak':
            if (title == 'Racha de 7 días') {
              shouldUnlock = currentStreak >= 7;
            }
            break;

          case 'budget':
            if (title == 'Presupuesto cumplido') {
              final now = DateTime.now();
              final prev = DateTime(now.year, now.month - 1, 1);
              final prevMonth =
                  '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
              final prevBudget = await _budgetService.getBudgetByMonth(
                userId,
                prevMonth,
              );
              if (prevBudget != null) {
                final prevExpenses = await _transactionService.getUserExpenses(
                  userId,
                  month: prevMonth,
                );
                final spent = prevExpenses.fold<double>(
                  0,
                  (total, expense) => total + expense.amount,
                );
                shouldUnlock = spent <= prevBudget.monthlyLimit;
              }
            }
            break;

          case 'savings':
            if (title == 'Ahorrador novato') {
              final totalIncome = incomes.fold<double>(
                0,
                (total, income) => total + income.amount,
              );
              final totalExpense = expenses.fold<double>(
                0,
                (total, expense) => total + expense.amount,
              );
              final savings = totalIncome - totalExpense;
              final savingsPercentage = totalIncome > 0
                  ? (savings / totalIncome) * 100
                  : 0;
              shouldUnlock =
                  incomes.isNotEmpty &&
                  expenses.length >= 5 &&
                  savingsPercentage >= 10;
            }
            break;
        }

        // Si debe desbloquearse
        if (shouldUnlock) {
          final key = template['key'] as String;
          final docId = '${userId}_$key';
          final achievement = Achievement(
            id: docId,
            userId: userId,
            title: title,
            description: template['description'] as String,
            icon: template['icon'] as String,
            points: template['points'] as int,
            category: template['category'] as String,
            unlockedAt: DateTime.now(),
          );
          await _db
              .collection('achievements')
              .doc(docId)
              .set(achievement.toMap(), SetOptions(merge: true));
          unlockedAchievements.add(achievement);
          await _addPoints(userId, template['points'] as int);
        }
      }

      return unlockedAchievements;
    } catch (e) {
      print('Error verificando logros: $e');
      return [];
    }
  }

  /// Mantiene la racha diaria de transacciones en el documento del usuario.
  Future<void> _updateStreak(String userId) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final now = DateTime.now();
        final today =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final yesterdayDate = now.subtract(const Duration(days: 1));
        final yesterday =
            '${yesterdayDate.year}-${yesterdayDate.month.toString().padLeft(2, '0')}-${yesterdayDate.day.toString().padLeft(2, '0')}';

        final lastTxDate = data['lastTxDate'] as String?;
        final currentStreak = (data['currentStreak'] ?? 0) as int;

        if (lastTxDate == today) return;
        final newStreak = lastTxDate == yesterday ? currentStreak + 1 : 1;
        tx.update(userRef, {'currentStreak': newStreak, 'lastTxDate': today});
      });
    } catch (e) {
      print('Error actualizando racha: $e');
    }
  }

  /// Obtener logros del usuario
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final snapshot = await _db
          .collection('achievements')
          .where('userId', isEqualTo: userId)
          .orderBy('unlockedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Achievement.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo logros: $e');
      return [];
    }
  }

  // ========== POINTS & LEVELS ==========

  /// Agregar puntos al usuario y actualizar nivel
  Future<void> _addPoints(String userId, int points) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) return;
        final current = (snap.data()!['points'] ?? 0) as int;
        final newPoints = current + points;
        tx.update(userRef, {
          'points': newPoints,
          'level': _calculateLevel(newPoints),
        });
      });
    } catch (e) {
      print('Error agregando puntos: $e');
    }
  }

  /// Calcular nivel basado en puntos
  String _calculateLevel(int points) {
    if (points >= 1000) return 'Maestro Financiero';
    if (points >= 750) return 'Estratégico';
    if (points >= 500) return 'Responsable';
    if (points >= 300) return 'Organizado';
    if (points >= 150) return 'Novato';
    return 'Principiante';
  }

  /// Punto de entrada único post-transacción. Se llama SIN await desde la UI.
  /// Nunca lanza excepciones.
  Future<void> onTransactionRegistered(
    String userId, {
    required bool isExpense,
  }) async {
    await rewardAction(
      userId,
      isExpense ? 'expense_registered' : 'income_registered',
    );
    await _updateStreak(userId);
    await checkAndUnlockAchievements(userId);
  }

  /// Calcular nivel numérico basado en puntos (público)
  int calculateLevel(int points) {
    if (points >= 1000) return 6;
    if (points >= 750) return 5;
    if (points >= 500) return 4;
    if (points >= 300) return 3;
    if (points >= 150) return 2;
    return 1;
  }

  /// Obtener puntos necesarios para el siguiente nivel
  int pointsForNextLevel(int currentLevel) {
    switch (currentLevel) {
      case 1:
        return 150;
      case 2:
        return 300;
      case 3:
        return 500;
      case 4:
        return 750;
      case 5:
        return 1000;
      default:
        return 1000; // Nivel máximo
    }
  }

  /// Puntos mínimos del nivel actual.
  int pointsForCurrentLevel(int level) {
    switch (level) {
      case 1:
        return 0;
      case 2:
        return 150;
      case 3:
        return 300;
      case 4:
        return 500;
      case 5:
        return 750;
      default:
        return 1000;
    }
  }

  /// Obtener puntos y nivel actual del usuario
  Future<Map<String, dynamic>> getUserProgress(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {
          'points': 0,
          'level': 'Principiante',
          'nextLevel': 'Novato',
          'pointsToNextLevel': 150,
        };
      }

      final userData = userDoc.data()!;
      final points = userData['points'] ?? 0;
      final level = userData['level'] ?? 'Principiante';

      // Calcular próximo nivel
      final levelInfo = _getNextLevelInfo(points, level);

      return {
        'points': points,
        'level': level,
        'nextLevel': levelInfo['nextLevel'],
        'pointsToNextLevel': levelInfo['pointsNeeded'],
      };
    } catch (e) {
      print('Error obteniendo progreso: $e');
      return {
        'points': 0,
        'level': 'Principiante',
        'nextLevel': 'Novato',
        'pointsToNextLevel': 150,
      };
    }
  }

  /// Obtener información del próximo nivel
  Map<String, dynamic> _getNextLevelInfo(
    int currentPoints,
    String currentLevel,
  ) {
    final levels = [
      {'name': 'Principiante', 'minPoints': 0},
      {'name': 'Novato', 'minPoints': 150},
      {'name': 'Organizado', 'minPoints': 300},
      {'name': 'Responsable', 'minPoints': 500},
      {'name': 'Estratégico', 'minPoints': 750},
      {'name': 'Maestro Financiero', 'minPoints': 1000},
    ];

    for (int i = 0; i < levels.length - 1; i++) {
      if (levels[i]['name'] == currentLevel) {
        final nextLevel = levels[i + 1];
        return {
          'nextLevel': nextLevel['name'],
          'pointsNeeded': (nextLevel['minPoints'] as int) - currentPoints,
        };
      }
    }

    return {'nextLevel': 'Máximo alcanzado', 'pointsNeeded': 0};
  }

  // ========== REWARDS ==========

  /// Dar puntos por acciones del usuario
  Future<void> rewardAction(String userId, String action) async {
    try {
      int points = 0;

      switch (action) {
        case 'expense_registered':
          points = AppConstants.pointsPerExpenseRegistered;
          break;
        case 'income_registered':
          points = AppConstants.pointsPerIncomeRegistered;
          break;
        case 'budget_set':
          points = 25;
          break;
        case 'budget_complied':
          points = AppConstants.pointsPerBudgetCompliance;
          break;
      }

      if (points > 0) {
        await _addPoints(userId, points);
      }
    } catch (e) {
      print('Error recompensando acción: $e');
    }
  }

  /// Stream de logros en tiempo real
  Stream<List<Achievement>> watchUserAchievements(String userId) {
    return _db
        .collection('achievements')
        .where('userId', isEqualTo: userId)
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Achievement.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
