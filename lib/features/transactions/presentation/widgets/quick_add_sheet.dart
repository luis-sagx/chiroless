import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../achievements/data/gamification_service.dart';
import '../../data/transaction_service.dart';
import '../pages/add_expense_page.dart';
import '../pages/add_income_page.dart';

class QuickAddResult {
  final bool isExpense;
  final double amount;

  QuickAddResult({required this.isExpense, required this.amount});
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amountController = TextEditingController();
  final _transactionService = TransactionService();
  final _gamificationService = GamificationService();
  final _firebaseService = FirebaseService();

  static const List<String> _expenseCategories = [
    'Alimentación',
    'Transporte',
    'Entretenimiento',
    'Salud',
    'Educación',
    'Vivienda',
    'Ropa',
    'Servicios',
    'Otros',
  ];

  static const List<String> _incomeSources = [
    'Salario',
    'Freelance',
    'Negocio',
    'Inversiones',
    'Regalo',
    'Beca',
    'Padres',
    'Otros',
  ];

  bool _isExpense = true;
  String _selectedCategory = _expenseCategories.first;
  String? _error;

  List<String> get _options =>
      _isExpense ? _expenseCategories : _incomeSources;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setMode(bool isExpense) {
    setState(() {
      _isExpense = isExpense;
      _selectedCategory = _options.first;
      _error = null;
    });
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Monto inválido');
      return;
    }

    final user = _firebaseService.currentUser;
    if (user == null) return;

    if (_isExpense) {
      final expense = Expense(
        id: null,
        userId: user.uid,
        amount: amount,
        category: _selectedCategory,
        description: '',
        date: DateTime.now(),
        isImpulsive: false,
      );
      unawaited(_transactionService.createExpense(expense));
      unawaited(
        _gamificationService.onTransactionRegistered(user.uid, isExpense: true),
      );
      Navigator.pop(context, QuickAddResult(isExpense: true, amount: amount));
      return;
    }

    final income = Income(
      id: null,
      userId: user.uid,
      amount: amount,
      source: _selectedCategory,
      description: '',
      date: DateTime.now(),
    );
    unawaited(_transactionService.createIncome(income));
    unawaited(
      _gamificationService.onTransactionRegistered(user.uid, isExpense: false),
    );
    Navigator.pop(context, QuickAddResult(isExpense: false, amount: amount));
  }

  void _openFullPage() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (context) =>
            _isExpense ? const AddExpensePage() : const AddIncomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('Gasto'),
                    selected: _isExpense,
                    selectedColor: AppTheme.primaryColor.withOpacity(0.14),
                    labelStyle: TextStyle(
                      color: _isExpense
                          ? AppTheme.primaryColor
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => _setMode(true),
                  ),
                  ChoiceChip(
                    label: const Text('Ingreso'),
                    selected: !_isExpense,
                    selectedColor: AppTheme.secondaryColor.withOpacity(0.18),
                    labelStyle: TextStyle(
                      color: !_isExpense
                          ? AppTheme.secondaryColor
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => _setMode(false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '\$',
                  hintText: '0.00',
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options.map((option) {
                  final selected = option == _selectedCategory;
                  final color = _isExpense
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryColor;
                  return ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    selectedColor: color.withOpacity(0.14),
                    labelStyle: TextStyle(
                      color: selected ? color : Colors.grey.shade700,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = option);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isExpense
                        ? AppTheme.primaryColor
                        : AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openFullPage,
                child: const Text('Más opciones'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
