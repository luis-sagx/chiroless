import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../../models/budget_model.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../transactions/data/transaction_service.dart';
import '../../../budget/data/budget_service.dart';
import '../../../budget/presentation/pages/add_budget_page.dart';
import '../widgets/budget_pace_chart.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/monthly_trend_chart.dart';

class StatisticsPage extends StatefulWidget {
  /// Cuando notifica, la página recarga sus datos.
  final Listenable? refreshListenable;

  const StatisticsPage({super.key, this.refreshListenable});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _firebaseService = FirebaseService();
  final _transactionService = TransactionService();
  final _budgetService = BudgetService();

  bool _isLoading = true;
  bool _trendLoading = false;
  String? _loadError;
  String? _trendError;
  Map<String, double> _expensesByCategory = {};
  double _totalIncome = 0;
  double _totalExpense = 0;
  Map<String, dynamic>? _budgetStatus;
  int _trendMonths = 6;
  int _trendRequest = 0;
  List<MonthTotals> _monthTotals = [];
  List<Expense> _monthExpenses = [];
  final Map<String, MonthTotals> _cachedTotals = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.refreshListenable?.addListener(_loadData);
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final trendRequest = ++_trendRequest;
    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _trendLoading = false;
      _loadError = null;
      _trendError = null;
      _monthTotals = [];
      _cachedTotals.clear();
    });

    try {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final current = await Future.wait<dynamic>([
        _transactionService.getUserExpenses(
          user.uid,
          month: month,
          rethrowOnError: true,
        ),
        _transactionService.getUserIncomes(
          user.uid,
          month: month,
          rethrowOnError: true,
        ),
        _budgetService.getCurrentBudget(user.uid, rethrowOnError: true),
      ]);
      final expenses = current[0] as List<Expense>;
      final incomes = current[1] as List<Income>;
      final budget = current[2] as Budget?;
      final totalExpense = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );
      final totalIncome = incomes.fold<double>(
        0,
        (sum, income) => sum + income.amount,
      );
      final categories = <String, double>{};
      for (final expense in expenses) {
        categories.update(
          expense.category,
          (total) => total + expense.amount,
          ifAbsent: () => expense.amount,
        );
      }
      final currentTotals = MonthTotals(
        month: month,
        income: totalIncome,
        expense: totalExpense,
      );
      if (!mounted || trendRequest != _trendRequest) return;
      setState(() {
        _totalIncome = totalIncome;
        _totalExpense = totalExpense;
        _expensesByCategory = categories;
        _budgetStatus = BudgetService.calculateBudgetStatus(
          budget,
          expenses,
          month,
        );
        _cachedTotals[month] = currentTotals;
        _monthExpenses = expenses;
        _isLoading = false;
        _trendLoading = true;
      });
      try {
        final totals = await _transactionService.getLastMonthsTotals(
          user.uid,
          months: _trendMonths,
          knownTotals: Map.of(_cachedTotals),
        );
        if (!mounted || trendRequest != _trendRequest) return;
        setState(() {
          _monthTotals = totals;
          _cachedTotals.addEntries(
            totals.map((total) => MapEntry(total.month, total)),
          );
          _trendLoading = false;
        });
      } catch (e) {
        if (!mounted || trendRequest != _trendRequest) return;
        setState(() {
          _trendLoading = false;
          _trendError = 'No se pudo cargar la tendencia';
        });
      }
    } catch (e) {
      if (mounted && trendRequest == _trendRequest) {
        setState(() {
          _isLoading = false;
          _loadError = 'No se pudieron cargar las estadísticas';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changeTrendMonths(int months) async {
    if (months == _trendMonths) return;
    final user = _firebaseService.currentUser;
    if (user == null) return;
    final previousMonths = _trendMonths;
    final request = ++_trendRequest;
    setState(() {
      _trendMonths = months;
      _trendLoading = true;
      _trendError = null;
    });
    try {
      final totals = await _transactionService.getLastMonthsTotals(
        user.uid,
        months: months,
        knownTotals: Map.of(_cachedTotals),
      );
      if (mounted && request == _trendRequest) {
        setState(() {
          _monthTotals = totals;
          _cachedTotals.addEntries(
            totals.map((total) => MapEntry(total.month, total)),
          );
          _trendLoading = false;
          _trendError = null;
        });
      }
    } catch (_) {
      if (mounted && request == _trendRequest) {
        setState(() {
          _trendMonths = previousMonths;
          _trendLoading = false;
          _trendError = 'No se pudo cargar la tendencia';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la tendencia')),
        );
      }
    }
  }

  Future<void> _retryTrend() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    final request = ++_trendRequest;
    setState(() {
      _trendLoading = true;
      _trendError = null;
    });
    try {
      final totals = await _transactionService.getLastMonthsTotals(
        user.uid,
        months: _trendMonths,
        knownTotals: Map.of(_cachedTotals),
      );
      if (!mounted || request != _trendRequest) return;
      setState(() {
        _monthTotals = totals;
        _cachedTotals.addEntries(
          totals.map((total) => MapEntry(total.month, total)),
        );
        _trendLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _trendRequest) return;
      setState(() {
        _trendLoading = false;
        _trendError = 'No se pudo cargar la tendencia';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            TextButton(onPressed: _loadData, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final hasData = _expensesByCategory.isNotEmpty || _totalIncome > 0;
    final now = DateTime.now();
    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final currentMonth = '${monthNames[now.month - 1]} ${now.year}';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Resumen de $currentMonth',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Budget Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Presupuesto de $currentMonth',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (_budgetStatus?['hasBudget'] == true)
                  TextButton.icon(
                    onPressed: () async {
                      final budget = _budgetStatus?['budget'] as Budget?;
                      if (budget == null) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddBudgetPage(
                            existingBudget: budget,
                            isInherited: _budgetStatus?['isInherited'] == true,
                          ),
                        ),
                      );
                      if (result == true && mounted) _loadData();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                if (_budgetStatus == null || !_budgetStatus!['hasBudget'])
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddBudgetPage(),
                        ),
                      );
                      if (result == true) {
                        _loadData(); // Reload data
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Crear'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_budgetStatus?['hasBudget'] == true)
              Text(
                _budgetStatus?['isInherited'] == true
                    ? 'Viene de un mes anterior y se repetirá hasta que lo cambies.'
                    : 'Se repetirá automáticamente cada mes hasta que lo cambies.',
              ),
            const Text(
              'Límite de gastos para este mes',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_budgetStatus != null && _budgetStatus!['hasBudget']) ...[
              _buildBudgetProgress(),
              BudgetPaceChart(
                expenses: _monthExpenses,
                budgetLimit: (_budgetStatus!['totalLimit'] as num).toDouble(),
              ),
            ] else ...[
              _buildNoBudgetCard(),
            ],

            const SizedBox(height: 24),

            if (_monthTotals.isNotEmpty ||
                (!_trendLoading && _trendError == null))
              MonthlyTrendChart(
                data: _monthTotals,
                months: _trendMonths,
                onMonthsChanged: _changeTrendMonths,
              ),
            if (_trendLoading) const LinearProgressIndicator(),
            if (_trendError != null)
              Row(
                children: [
                  Expanded(child: Text(_trendError!)),
                  TextButton(
                    onPressed: _retryTrend,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Expenses by Category
            if (_expensesByCategory.isNotEmpty) ...[
              Text(
                'Gastos por categoría · $currentMonth',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Todos los gastos registrados este mes',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              CategoryDonutChart(expensesByCategory: _expensesByCategory),
              _buildCategoryList(),
            ],

            // Empty State
            if (!hasData) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.insert_chart_outlined,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin datos este mes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comienza a registrar transacciones',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgress() {
    if (_budgetStatus == null) return const SizedBox();

    final totalBudget = _budgetStatus!['totalLimit'] ?? 0.0;
    final totalSpent = _budgetStatus!['totalSpent'] ?? 0.0;
    final percentage = _budgetStatus!['percentageUsed'] ?? 0.0;
    final remaining = totalBudget - totalSpent;

    Color progressColor = AppTheme.secondaryColor;
    if (percentage >= 100) {
      progressColor = AppTheme.errorColor;
    } else if (percentage >= 80) {
      progressColor = Colors.orange;
    }

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastado',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '\$${totalSpent.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Restante',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '\$${remaining.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: remaining < 0 ? AppTheme.errorColor : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}% del presupuesto',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin presupuesto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Define un límite mensual para controlar tus gastos',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddBudgetPage()),
              );
              if (result == true) {
                _loadData();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear Presupuesto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    final sortedCategories = _expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmount = sortedCategories.isNotEmpty
        ? sortedCategories.first.value
        : 1.0;

    return Column(
      children: sortedCategories.map((entry) {
        final info = TransactionCategories.expenseInfo(entry.key);
        final share = _totalExpense > 0
            ? entry.value / _totalExpense * 100
            : 0.0;
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info.icon, color: info.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '\$${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: (entry.value / maxAmount).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: info.color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(info.color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${share.toStringAsFixed(0)} % del total',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
