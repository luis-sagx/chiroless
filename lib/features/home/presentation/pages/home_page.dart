import '../../../../core/constants/transaction_categories.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/lazy_indexed_stack.dart';
import '../../../../core/services/shortcut_service.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../budget/data/budget_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../admin/presentation/pages/admin_page.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/user_service.dart';
import '../../../../models/user_model.dart';
import '../../../transactions/presentation/pages/add_expense_page.dart';
import '../../../transactions/presentation/pages/add_income_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../analytics/presentation/pages/statistics_page.dart';
import '../../../achievements/presentation/pages/achievements_page.dart';
import '../../../achievements/presentation/widgets/gamification_session.dart';
import '../../../achievements/presentation/widgets/savings_leaderboard_sync.dart';
import '../../../achievements/presentation/widgets/compact_level_indicator.dart';
import '../../../achievements/data/gamification_service.dart';
import '../../../achievements/presentation/widgets/reward_feedback.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../profile/presentation/pages/edit_profile_page.dart';
import '../../../profile/presentation/pages/help_page.dart';
import '../../../profile/presentation/pages/about_page.dart';
import '../../../profile/presentation/pages/terms_conditions_page.dart';
import '../../../ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../../transactions/data/transaction_service.dart';
import '../../../transactions/data/recurring_transaction_service.dart';
import '../../../transactions/data/category_service.dart';
import '../../../transactions/presentation/pages/category_management_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../transactions/presentation/widgets/quick_add_sheet.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

enum _HomeTransactionAction { edit, delete }

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<AppUser?>? _userSubscription;
  bool _hasUserSnapshot = false;
  final service = FirebaseService();
  final userService = UserService();
  final transactionService = TransactionService();
  final _recurringTransactionService = RecurringTransactionService();
  final _categoryService = CategoryService();
  final _budgetService = BudgetService();
  bool _widgetHidden = false;
  int _selectedIndex = 0;
  AppUser? appUser;
  bool isLoadingUser = true;
  double totalBalance = 0.0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  List<dynamic> recentTransactions = []; // Mix of Expense and Income
  bool isLoadingTransactions = true;
  List<String> _topExpenseCategories = [];
  final ValueNotifier<int> _dataVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    final uid = service.currentUser?.uid;
    if (uid != null) {
      _userSubscription = userService
          .getUserStream(uid)
          .listen(
            (user) {
              if (mounted) {
                setState(() {
                  _hasUserSnapshot = true;
                  appUser = user;
                  isLoadingUser = false;
                });
              }
            },
            onError: (Object error) {
              if (mounted) setState(() => isLoadingUser = false);
            },
          );
    }
    initializeDateFormatting('es', null);
    _loadUser(reconcileRecurring: true);
    ShortcutService.pending.addListener(_handleShortcut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleShortcut());
    HomeWidgetService.isHidden().then((v) {
      if (mounted) setState(() => _widgetHidden = v);
    });
  }

  @override
  void dispose() {
    ShortcutService.pending.removeListener(_handleShortcut);
    _userSubscription?.cancel();
    _dataVersion.dispose();
    super.dispose();
  }

  void _handleShortcut() {
    final type = ShortcutService.pending.value;
    if (type == null || !mounted) return;
    ShortcutService.pending.value = null;
    _showAddTransactionOptions(isExpense: type != ShortcutService.addIncome);
  }

  Future<void> _loadUser({bool reconcileRecurring = false}) async {
    final user = service.currentUser;
    if (user != null) {
      try {
        await _categoryService.ensureInitialized(user.uid);
      } catch (error) {
        // Category loading in individual forms can retry without blocking Home.
        print('Error inicializando categorías: $error');
      }
      if (reconcileRecurring) {
        try {
          await _recurringTransactionService.reconcileForUser(user.uid);
        } catch (error) {
          // A temporary Firestore error must not prevent the user entering Home.
          print('Error conciliando movimientos periódicos: $error');
        }
      }
      final userData = await userService.getUser(user.uid);
      if (mounted) {
        setState(() {
          // Once live data arrives, a slower fallback read cannot replace it.
          if (!_hasUserSnapshot) {
            appUser = userData;
          }
          isLoadingUser = false;
        });
      }
      await _loadTransactionData();
    }
  }

  Future<void> _loadTransactionData() async {
    final user = service.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() => isLoadingTransactions = true);
    }

    try {
      final results = await Future.wait([
        transactionService.getAllUserExpenses(user.uid),
        transactionService.getAllUserIncomes(user.uid),
      ]);
      final allExpenses = results[0] as List<Expense>;
      final allIncomes = results[1] as List<Income>;
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final expenses = allExpenses
          .where((expense) => expense.month == currentMonth)
          .toList();
      final incomes = allIncomes
          .where((income) => income.month == currentMonth)
          .toList();
      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );
      final totalIncomes = incomes.fold<double>(
        0,
        (sum, income) => sum + income.amount,
      );
      final openingDate = appUser?.openingBalanceDate ?? DateTime.now();
      final openingDateStart = DateTime(
        openingDate.year,
        openingDate.month,
        openingDate.day,
      );
      final openingExpenses = allExpenses.where(
        (expense) => !expense.date.isBefore(openingDateStart),
      );
      final openingIncomes = allIncomes.where(
        (income) => !income.date.isBefore(openingDateStart),
      );
      final balanceFromOpening =
          (appUser?.openingBalanceAmount ?? 0) +
          openingIncomes.fold<double>(0, (sum, income) => sum + income.amount) -
          openingExpenses.fold<double>(
            0,
            (sum, expense) => sum + expense.amount,
          );
      final List<dynamic> combined = [...expenses, ...incomes];
      combined.sort((a, b) => b.date.compareTo(a.date));
      final counts = <String, int>{};
      for (final e in expenses) {
        counts[e.category] = (counts[e.category] ?? 0) + 1;
      }
      final topCategories = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

      if (mounted) {
        setState(() {
          totalBalance = balanceFromOpening;
          totalIncome = totalIncomes;
          totalExpense = totalExpenses;
          recentTransactions = combined.take(5).toList();
          _topExpenseCategories = topCategories;
          isLoadingTransactions = false;
        });
        unawaited(_syncWidget());
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        setState(() => isLoadingTransactions = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      await service.logout();

      // Navigate to LoginPage
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      // Pop loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddExpensePage()),
    );
    if (result == true) {
      _loadUser(); // Reload to update balance
      _dataVersion.value++;
    }
  }

  Future<void> _navigateToAddIncome() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddIncomePage()),
    );
    if (result == true) {
      _loadUser(); // Reload to update balance
      _dataVersion.value++;
    }
  }

  Future<void> _navigateToTransactions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsPage()),
    );
    if (!mounted) return;
    _loadTransactionData();
    _dataVersion.value++;
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    if (result == true) {
      _loadUser(); // Reload to update user data
    }
  }

  void _showAddTransactionOptions({bool isExpense = true}) async {
    final result = await showModalBottomSheet<QuickAddResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => QuickAddSheet(
        initialIsExpense: isExpense,
        expenseCategoryOrder: _topExpenseCategories,
      ),
    );
    if (result != null && mounted) {
      _applyOptimisticTransaction(result);
      _dataVersion.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedActionFeedback(
              result.isExpense ? 'Gasto guardado' : 'Ingreso guardado',
              result.reward,
            ),
          ),
          backgroundColor: AppTheme.incomeColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyOptimisticTransaction(QuickAddResult result) {
    final now = DateTime.now();
    final isCurrentMonth =
        result.date.year == now.year && result.date.month == now.month;
    final openingDate = appUser?.openingBalanceDate ?? DateTime.now();
    final openingDateStart = DateTime(
      openingDate.year,
      openingDate.month,
      openingDate.day,
    );
    final affectsBalance = !result.date.isBefore(openingDateStart);
    if (!isCurrentMonth && !affectsBalance) return;
    setState(() {
      if (isCurrentMonth && result.isExpense) {
        totalExpense += result.amount;
      } else if (isCurrentMonth) {
        totalIncome += result.amount;
      }
      if (affectsBalance && result.isExpense) {
        totalBalance -= result.amount;
      } else if (affectsBalance) {
        totalBalance += result.amount;
      }
    });
    if (isCurrentMonth && result.isExpense) unawaited(_syncWidget());
  }

  // Actualiza el widget de pantalla de inicio con el gasto del mes.
  Future<void> _syncWidget() async {
    final user = service.currentUser;
    if (user == null) return;
    final budget = await _budgetService.getCurrentBudget(user.uid);
    await HomeWidgetService.update(
      spent: totalExpense,
      limit: budget?.monthlyLimit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = service.currentUser?.uid;
    final content = GamificationSession(
      userId: userId,
      points: appUser?.points,
      onDailyVisit: () => userId == null
          ? Future.value(const RewardResult(confirmed: false))
          : GamificationService().rewardDailyVisit(userId),
      child: LazyIndexedStack(
        index: _selectedIndex,
        builders: [
          (_) => _buildHomeContent(),
          (_) => StatisticsPage(refreshListenable: _dataVersion),
          (_) => const SizedBox.shrink(), // Placeholder for center button
          (_) => const AchievementsPage(),
          (_) => _buildProfileContent(),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: userId == null
            ? content
            : SavingsLeaderboardSync(userId: userId, child: content),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIAssistantPage()),
          );
        },
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
        tooltip: 'Asistente IA',
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (index == 2) {
              // Botón central - mostrar opciones
              _showAddTransactionOptions();
            } else {
              setState(() {
                _selectedIndex = index;
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Estadísticas',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              label: 'Agregar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Logros',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final user = service.currentUser;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¡Hola!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appUser?.name ??
                                user?.email?.split('@')[0] ??
                                'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (appUser != null)
                            CompactLevelIndicator(
                              points: appUser!.points,
                              onTap: () => setState(() => _selectedIndex = 3),
                            ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Balance Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: isLoadingTransactions
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Balance Total',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: totalBalance),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => Text(
                                '\$${value.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: totalBalance >= 0
                                      ? Colors.white
                                      : Colors.red.shade200,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBalanceItem(
                                    'Ingresos',
                                    '\$${totalIncome.toStringAsFixed(0)}',
                                    Icons.arrow_downward,
                                    AppTheme.incomeColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildBalanceItem(
                                    'Gastos',
                                    '\$${totalExpense.toStringAsFixed(0)}',
                                    Icons.arrow_upward,
                                    AppTheme.expenseColor,
                                  ),
                                ),
                              ],
                            ),
                            if (appUser != null &&
                                !appUser!.openingBalanceConfigured) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Configura el dinero que tenías al comenzar '
                                'para calcular tu saldo disponible.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _navigateToEditProfile,
                                icon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                label: const Text('Configurar saldo inicial'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),

        // Quick Actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acciones rápidas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        'Agregar\nIngreso',
                        Icons.add_circle_outline,
                        AppTheme.secondaryColor,
                        () => _navigateToAddIncome(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        'Agregar\nGasto',
                        Icons.remove_circle_outline,
                        AppTheme.accentColor,
                        () => _navigateToAddExpense(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        'Ver\nReportes',
                        Icons.bar_chart,
                        AppTheme.primaryColor,
                        () {
                          setState(() => _selectedIndex = 1);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Recent Transactions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Transacciones recientes',
                        style: Theme.of(context).textTheme.headlineMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToTransactions,
                      child: const Text('Ver todo'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                isLoadingTransactions
                    ? const Center(child: CircularProgressIndicator())
                    : recentTransactions.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: recentTransactions
                            .map(
                              (transaction) =>
                                  _buildTransactionItem(transaction),
                            )
                            .toList(),
                      ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildProfileContent() {
    final user = service.currentUser;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('Perfil', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 32),

            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        appUser?.name.isNotEmpty == true
                            ? appUser!.name[0].toUpperCase()
                            : (user?.email?[0].toUpperCase() ?? 'U'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appUser?.name ?? user?.email?.split('@')[0] ?? 'Usuario',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appUser?.level ?? 'Principiante',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Menu Items
            if (user?.email == dotenv.env['ADMIN_EMAIL'])
              _buildMenuItem(Icons.analytics, 'Panel Investigador', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPage()),
                );
              }),

            _buildMenuItem(
              Icons.person_outline,
              'Editar perfil',
              _navigateToEditProfile,
            ),
            _buildMenuItem(
              Icons.category_outlined,
              'Administrar categorías',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryManagementPage(),
                  ),
                );
              },
            ),
            _buildMenuItem(Icons.help_outline, 'Ayuda', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpPage()),
              );
            }),
            _buildMenuItem(Icons.info_outline, 'Acerca de', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            }),
            _buildMenuItem(
              Icons.description_outlined,
              'Términos y condiciones',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsPage(),
                  ),
                );
              },
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              _buildMenuItem(
                Icons.visibility_off_outlined,
                'Ocultar montos en widget',
                () => _setWidgetHidden(!_widgetHidden),
                trailing: Switch(
                  value: _widgetHidden,
                  onChanged: _setWidgetHidden,
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ),

            const SizedBox(height: 16),

            // Logout Button
            InkWell(
              onTap: _logout,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.errorColor, size: 24),
                    const SizedBox(width: 16),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(dynamic transaction) {
    final bool isExpense = transaction is Expense;
    final String title = isExpense ? transaction.category : transaction.source;
    final double amount = isExpense ? transaction.amount : transaction.amount;
    final DateTime date = transaction.date;
    final Color color = isExpense
        ? AppTheme.expenseColor
        : AppTheme.incomeColor;
    final CategoryInfo info = isExpense
        ? TransactionCategories.expenseInfo(title)
        : TransactionCategories.incomeInfo(title);

    return GestureDetector(
      onLongPress: () => _showTransactionActions(transaction, isExpense),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(info.icon, color: info.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM yyyy', 'es').format(date),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransactionActions(
    dynamic transaction,
    bool isExpense,
  ) async {
    final action = await showModalBottomSheet<_HomeTransactionAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar movimiento'),
              onTap: () => Navigator.pop(context, _HomeTransactionAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar movimiento'),
              textColor: Colors.red,
              onTap: () =>
                  Navigator.pop(context, _HomeTransactionAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == _HomeTransactionAction.edit) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => isExpense
              ? AddExpensePage(expense: transaction as Expense)
              : AddIncomePage(income: transaction as Income),
        ),
      );
      if (result == true && mounted) {
        await _refreshAfterTransactionChange();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text('¿Seguro que quieres eliminar este movimiento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = isExpense
        ? (transaction as Expense).id
        : (transaction as Income).id;
    final deleted =
        id != null &&
        (isExpense
            ? await transactionService.deleteExpense(id)
            : await transactionService.deleteIncome(id));
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el movimiento')),
      );
      return;
    }

    await _refreshAfterTransactionChange();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Movimiento eliminado')));
    }
  }

  Future<void> _refreshAfterTransactionChange() async {
    await _loadTransactionData();
    if (mounted) _dataVersion.value++;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay transacciones aún',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza a registrar tus ingresos y gastos',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _setWidgetHidden(bool value) {
    setState(() => _widgetHidden = value);
    HomeWidgetService.setHidden(value);
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                  size: 24,
                ),
          ],
        ),
      ),
    );
  }
}
