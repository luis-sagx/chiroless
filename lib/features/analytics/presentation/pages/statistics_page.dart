import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../transactions/data/transaction_service.dart';
import '../../../budget/data/budget_service.dart';
import '../../data/metrics_service.dart';
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
  final _metricsService = MetricsService();

  bool _isLoading = true;
  Map<String, double> _expensesByCategory = {};
  double _totalIncome = 0;
  double _totalExpense = 0;
  Map<String, dynamic>? _budgetStatus;
  String _period = 'PRE';
  List<MonthTotals> _monthTotals = [];
  List<Expense> _monthExpenses = [];

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
    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final results = await Future.wait<dynamic>([
        _metricsService.determinePeriod(user.uid),
        _transactionService.getMonthSummary(user.uid, month: month),
        _budgetService.getBudgetStatus(user.uid),
        _transactionService.getLastMonthsTotals(user.uid),
        _transactionService.getUserExpenses(user.uid, month: month),
      ]);
      final summary = results[1] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _period = results[0] as String;
        _totalIncome = (summary['totalIncomes'] ?? 0.0).toDouble();
        _totalExpense = (summary['totalExpenses'] ?? 0.0).toDouble();
        _expensesByCategory = Map<String, double>.from(
          summary['expensesByCategory'] ?? {},
        );
        _budgetStatus = results[2] as Map<String, dynamic>;
        _monthTotals = results[3] as List<MonthTotals>;
        _monthExpenses = results[4] as List<Expense>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final balance = _totalIncome - _totalExpense;
    final hasData = _expensesByCategory.isNotEmpty || _totalIncome > 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Period Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estadísticas',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _period == 'PRE'
                        ? Colors.blue.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Periodo $_period',
                    style: TextStyle(
                      color: _period == 'PRE'
                          ? Colors.blue.shade900
                          : Colors.green.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Balance Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Balance del Mes',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBalanceItem(
                          'Ingresos',
                          _totalIncome,
                          Icons.arrow_downward,
                          AppTheme.incomeColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBalanceItem(
                          'Gastos',
                          _totalExpense,
                          Icons.arrow_upward,
                          AppTheme.expenseColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Budget Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Presupuesto',
                  style: Theme.of(context).textTheme.headlineMedium,
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

            if (_monthTotals.any((t) => t.income > 0 || t.expense > 0))
              MonthlyTrendChart(data: _monthTotals),

            const SizedBox(height: 24),

            // Expenses by Category
            if (_expensesByCategory.isNotEmpty) ...[
              Text(
                'Gastos por Categoría',
                style: Theme.of(context).textTheme.headlineMedium,
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

  Widget _buildBalanceItem(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
