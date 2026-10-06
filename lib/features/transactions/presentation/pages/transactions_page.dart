import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../data/transaction_service.dart';
import 'add_expense_page.dart';
import 'add_income_page.dart';

/// Movimientos de un mes. Consultar un mes a la vez mantiene rápida la pantalla.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _service = TransactionService();
  final _firebase = FirebaseService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Object> _transactions = [];
  bool _loading = true;
  String? _error;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final version = ++_loadVersion;
    final user = _firebase.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Inicia sesión para ver tus movimientos';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _service.getUserExpenses(
          user.uid,
          month: _monthKey,
          rethrowOnError: true,
        ),
        _service.getUserIncomes(
          user.uid,
          month: _monthKey,
          rethrowOnError: true,
        ),
      ]);
      if (!mounted || version != _loadVersion) return;
      final entries = <Object>[
        ...(results[0] as List<Expense>),
        ...(results[1] as List<Income>),
      ]..sort((a, b) => _date(b).compareTo(_date(a)));
      setState(() => _transactions = entries);
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = 'No se pudieron cargar los movimientos');
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime _date(Object item) =>
      item is Expense ? item.date : (item as Income).date;

  void _shiftMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    _load();
  }

  Future<void> _edit(Object item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => item is Expense
            ? AddExpensePage(expense: item)
            : AddIncomePage(income: item as Income),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(Object item) async {
    final isExpense = item is Expense;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar ${isExpense ? 'gasto' : 'ingreso'}?'),
        content: const Text('Este movimiento se quitará de tus cifras.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = isExpense ? item.id : (item as Income).id;
    final saved =
        id != null &&
        (isExpense
            ? await _service.deleteExpense(id)
            : await _service.deleteIncome(id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Movimiento eliminado'
              : 'No se pudo eliminar. Inténtalo de nuevo.',
        ),
      ),
    );
    if (saved) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mes anterior',
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'es').format(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: isCurrent ? null : () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Mes siguiente',
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _load,
                      child: Text('$_error. Reintentar'),
                    ),
                  )
                : _transactions.isEmpty
                ? const Center(child: Text('No hay movimientos este mes'))
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final item = _transactions[index];
                      final expense = item is Expense;
                      final label = expense
                          ? item.category
                          : (item as Income).source;
                      final amount = expense
                          ? item.amount
                          : (item as Income).amount;
                      return ListTile(
                        leading: Icon(
                          expense ? Icons.arrow_upward : Icons.arrow_downward,
                          color: expense
                              ? AppTheme.expenseColor
                              : AppTheme.incomeColor,
                        ),
                        title: Text(label),
                        subtitle: Text(
                          DateFormat('d MMM yyyy', 'es').format(_date(item)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${expense ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Opciones de $label',
                              onSelected: (action) => action == 'edit'
                                  ? _edit(item)
                                  : _delete(item),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _edit(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
