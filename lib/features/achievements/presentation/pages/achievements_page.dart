import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../models/achievement_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../../models/budget_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/user_service.dart';
import '../../../transactions/data/transaction_service.dart';
import '../../data/gamification_service.dart';
import '../../data/gamification_rules.dart';
import '../widgets/personal_progress_card.dart';
import '../widgets/savings_leaderboard_panel.dart';

class AchievementsPage extends StatefulWidget {
  final Stream<AppUser?>? userStream;
  final Stream<List<Achievement>>? achievementsStream;
  final Stream<List<Expense>>? expensesStream;
  final Stream<List<Income>>? incomesStream;
  final Stream<List<Budget>>? budgetsStream;
  final Stream<List<Expense>>? previousExpensesStream;
  const AchievementsPage({
    super.key,
    this.userStream,
    this.achievementsStream,
    this.expensesStream,
    this.incomesStream,
    this.budgetsStream,
    this.previousExpensesStream,
  });
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AppUser? _user;
  List<Achievement> _achievements = [];
  List<Expense>? _expenses;
  List<Income>? _incomes;
  List<Budget>? _budgets;
  List<Expense>? _previousExpenses;
  final Set<Object> _failedStreams = {};
  String? get _error => _failedStreams.isEmpty
      ? null
      : 'No pudimos actualizar tu progreso. Los datos anteriores se conservan.';
  bool _waiting = true;
  bool _showLeaderboard = false;
  @override
  void initState() {
    super.initState();
    final uid = widget.userStream == null
        ? FirebaseService().currentUser?.uid
        : null;
    if (uid == null && widget.userStream == null) {
      _waiting = false;
      return;
    }
    void listen<T>(Stream<T> stream, void Function(T) update) {
      _subscriptions.add(
        stream.listen(
          (value) {
            if (mounted) {
              setState(() {
                _failedStreams.remove(stream);
                update(value);
              });
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _waiting = false;
                _failedStreams.add(stream);
              });
            }
          },
        ),
      );
    }

    listen<AppUser?>(widget.userStream ?? UserService().getUserStream(uid!), (
      value,
    ) {
      _user = value;
      _waiting = false;
    });
    listen<List<Achievement>>(
      widget.achievementsStream ??
          GamificationService().watchUserAchievements(uid!),
      (value) => _achievements = value,
    );
    listen<List<Expense>>(
      widget.expensesStream ?? TransactionService().watchUserExpenses(uid!),
      (value) => _expenses = value,
    );
    listen<List<Income>>(
      widget.incomesStream ?? TransactionService().watchUserIncomes(uid!),
      (value) => _incomes = value,
    );
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    final month =
        '${previous.year}-${previous.month.toString().padLeft(2, '0')}';
    listen<List<Budget>>(
      widget.budgetsStream ??
          (uid == null
              ? Stream.value(<Budget>[])
              : FirebaseFirestore.instance
                    .collection('budgets')
                    .where('userId', isEqualTo: uid)
                    .snapshots()
                    .map(
                      (snapshot) => snapshot.docs
                          .map((doc) => Budget.fromMap(doc.data(), doc.id))
                          .toList(),
                    )),
      (value) => _budgets = value,
    );
    listen<List<Expense>>(
      widget.previousExpensesStream ??
          (uid == null
              ? Stream.value(<Expense>[])
              : TransactionService().watchUserExpenses(uid, month: month)),
      (value) => _previousExpenses = value,
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Mi progreso'),
                icon: Icon(Icons.verified_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Ahorradores'),
                icon: Icon(Icons.leaderboard_outlined),
              ),
            ],
            selected: {_showLeaderboard},
            onSelectionChanged: (value) =>
                setState(() => _showLeaderboard = value.first),
          ),
        ),
        Expanded(
          child: _showLeaderboard && _user != null
              ? SavingsLeaderboardPanel(userId: _user!.uid)
              : _buildProgress(context),
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    if (_waiting) return const Center(child: CircularProgressIndicator());
    if (_user == null) {
      return Center(
        child: Text(_error ?? 'Inicia sesión para ver tu progreso.'),
      );
    }
    final unlocked = _achievements
        .where((a) => a.isUnlocked)
        .map((a) => a.title)
        .toSet();
    final pending = AchievementTemplates.templates
        .where((t) => !unlocked.contains(t['title']))
        .toList();
    final streak = GamificationRules.activeStreak(
      _user!.currentStreak,
      _user!.lastTxDate,
      DateTime.now(),
    );
    final expenses = _expenses ?? <Expense>[];
    final incomes = _incomes ?? <Income>[];
    final totalExpenses = expenses.fold<double>(
      0,
      (total, e) => total + e.amount,
    );
    final totalIncomes = incomes.fold<double>(
      0,
      (total, i) => total + i.amount,
    );
    final impulsive = expenses
        .where((e) => e.isImpulsive)
        .fold<double>(0, (total, e) => total + e.amount);
    final previous = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final previousMonth =
        '${previous.year}-${previous.month.toString().padLeft(2, '0')}';
    final budget = Budget.latestForMonth(_budgets ?? [], previousMonth);
    double progress(String key) => GamificationRules.achievementProgress(
      key,
      currentStreak: streak,
      expenseCount: expenses.length,
      incomeCount: incomes.length,
      totalExpenses: totalExpenses,
      totalIncomes: totalIncomes,
      impulsiveExpenses: impulsive,
      hasAnyTransaction: expenses.isNotEmpty || incomes.isNotEmpty,
      hasPreviousBudget: budget != null,
      previousExpenses: (_previousExpenses ?? []).fold<double>(
        0,
        (total, e) => total + e.amount,
      ),
      previousBudgetLimit: budget?.monthlyLimit ?? 0,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Logros y Progreso',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 20),
          PersonalProgressCard(user: _user!),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          const SizedBox(height: 20),
          if (pending.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu próxima acción',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${pending.first['title']} · +${pending.first['points']} puntos',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    !unlocked.contains('Primera transacción')
                        ? 'Registra tu primer ingreso o gasto real.'
                        : !unlocked.contains('Racha de 7 días')
                        ? 'Registra los movimientos reales del día. Racha: $streak de 7 días.'
                        : !unlocked.contains('Presupuesto cumplido')
                        ? 'Configura un presupuesto y mantén tus gastos dentro del límite mensual.'
                        : !unlocked.contains('Ahorrador novato')
                        ? 'Revisa tu ahorro del mes: al menos 10% de ingresos y ${expenses.length.clamp(0, 5)} de 5 gastos reales registrados.'
                        : 'Revisa tus compras impulsivas: ${expenses.length.clamp(0, 10)} de 10 gastos reales registrados; objetivo menor al 20% del importe.',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Registra tus finanzas para conocer tus hábitos.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            '${unlocked.length} de ${AchievementTemplates.templates.length} logros completados',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final template in AchievementTemplates.templates)
            _achievement(
              template,
              unlocked.contains(template['title']),
              progress(template['key'] as String),
            ),
        ],
      ),
    );
  }

  Widget _achievement(
    Map<String, dynamic> template,
    bool unlocked,
    double progress,
  ) {
    final key = template['key'] as String;
    final observable = key == 'budget_month'
        ? _budgets != null && _previousExpenses != null
        : _expenses != null && _incomes != null;
    const icons = {
      'star': Icons.star,
      'local_fire_department': Icons.local_fire_department,
      'check_circle': Icons.check_circle,
      'savings': Icons.savings,
      'psychology': Icons.psychology,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? AppTheme.secondaryColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icons[template['icon']] ?? Icons.emoji_events,
                color: unlocked
                    ? AppTheme.secondaryColor
                    : AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  template['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('+${template['points']} pts'),
            ],
          ),
          const SizedBox(height: 8),
          Text(template['description'] as String),
          const SizedBox(height: 12),
          if (unlocked)
            const Text(
              'Completado',
              style: TextStyle(color: AppTheme.secondaryColor),
            )
          else if (observable) ...[
            LinearProgressIndicator(
              value: progress,
              color: AppTheme.primaryColor,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}% de los requisitos · ${key == 'budget_month'
                  ? 'mes anterior'
                  : key == 'streak_7'
                  ? 'hábito diario'
                  : 'datos de este mes'}',
              style: const TextStyle(fontSize: 12),
            ),
          ] else
            Text(
              key == 'budget_month'
                  ? 'Se comprueba al cerrar el mes con presupuesto.'
                  : 'Cargando movimientos…',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}
