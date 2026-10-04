import '../../../../core/constants/transaction_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../admin/presentation/pages/admin_page.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/user_service.dart';
import '../../../../models/user_model.dart';
import '../../../transactions/presentation/pages/add_expense_page.dart';
import '../../../transactions/presentation/pages/add_income_page.dart';
import '../../../analytics/presentation/pages/statistics_page.dart';
import '../../../achievements/presentation/pages/achievements_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../profile/presentation/pages/edit_profile_page.dart';
import '../../../profile/presentation/pages/help_page.dart';
import '../../../profile/presentation/pages/about_page.dart';
import '../../../profile/presentation/pages/terms_conditions_page.dart';
import '../../../survey/presentation/pages/survey_page.dart';
import '../../../survey/data/survey_service.dart';
import '../../../ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../../transactions/data/transaction_service.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../transactions/presentation/widgets/quick_add_sheet.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final service = FirebaseService();
  final userService = UserService();
  final transactionService = TransactionService();
  final surveyService = SurveyService();
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
    initializeDateFormatting('es', null);
    _loadUser();
  }

  @override
  void dispose() {
    _dataVersion.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = service.currentUser;
    if (user != null) {
      final transactionsFuture = _loadTransactionData();
      final userData = await userService.getUser(user.uid);
      if (mounted) {
        setState(() {
          appUser = userData;
          isLoadingUser = false;
        });
      }
      await transactionsFuture;
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
        transactionService.getUserExpenses(user.uid),
        transactionService.getUserIncomes(user.uid),
      ]);
      final expenses = results[0] as List<Expense>;
      final incomes = results[1] as List<Income>;
      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );
      final totalIncomes = incomes.fold<double>(
        0,
        (sum, income) => sum + income.amount,
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
          totalBalance = totalIncomes - totalExpenses;
          totalIncome = totalIncomes;
          totalExpense = totalExpenses;
          recentTransactions = combined.take(5).toList();
          _topExpenseCategories = topCategories;
          isLoadingTransactions = false;
        });
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

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
    if (result == true) {
      _loadUser(); // Reload to update user data
    }
  }

  // Verificar si se puede mostrar la encuesta POST
  Future<bool> _canShowPostSurvey() async {
    if (appUser == null) return false;

    // Verificar si ya completó la encuesta POST
    final hasCompletedPost = await surveyService.hasCompletedPostSurvey(
      appUser!.uid,
    );
    if (hasCompletedPost) return false;

    // Verificar si han pasado 15+ días
    return surveyService.canCompletePostSurvey(appUser!.createdAt);
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
            result.isExpense ? 'Gasto guardado' : 'Ingreso guardado',
          ),
          backgroundColor: AppTheme.incomeColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyOptimisticTransaction(QuickAddResult result) {
    final now = DateTime.now();
    if (result.date.year != now.year || result.date.month != now.month) return;
    setState(() {
      if (result.isExpense) {
        totalExpense += result.amount;
        totalBalance -= result.amount;
      } else {
        totalIncome += result.amount;
        totalBalance += result.amount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeContent(),
            StatisticsPage(refreshListenable: _dataVersion),
            Container(), // Placeholder for center button
            const AchievementsPage(),
            _buildProfileContent(),
          ],
        ),
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
              color: Colors.black.withOpacity(0.05),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Estadísticas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Agregar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Logros',
            ),
            BottomNavigationBarItem(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¡Hola!',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
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
                      ],
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
                          color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
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
                            Text(
                              '\$${totalBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: totalBalance >= 0
                                    ? Colors.white
                                    : Colors.red.shade200,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transacciones recientes',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedIndex = 1),
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
                    color: AppTheme.primaryColor.withOpacity(0.1),
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
                      color: AppTheme.primaryColor.withOpacity(0.1),
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

            // Encuesta POST (solo si han pasado 15+ días)
            FutureBuilder<bool>(
              future: _canShowPostSurvey(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return _buildMenuItem(
                    Icons.assignment_outlined,
                    'Encuesta Final',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SurveyPage(surveyType: 'POST'),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
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
                  color: AppTheme.errorColor.withOpacity(0.1),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
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
              color: color.withOpacity(0.1),
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
                color: color.withOpacity(0.1),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
    );
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
              color: AppTheme.primaryColor.withOpacity(0.1),
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

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
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
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}
