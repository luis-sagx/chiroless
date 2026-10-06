import '../../../../core/constants/transaction_categories.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../data/transaction_service.dart';
import '../../../achievements/data/gamification_service.dart';
import '../../../budget/data/budget_service.dart';
import '../../../../core/services/notification_service.dart';

class AddExpensePage extends StatefulWidget {
  final Expense? expense;

  const AddExpensePage({Key? key, this.expense}) : super(key: key);

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _transactionService = TransactionService();
  final _firebaseService = FirebaseService();
  final _gamificationService = GamificationService();
  final _budgetService = BudgetService();
  final _notificationService = NotificationService();

  String _selectedCategory = TransactionCategories.expense.first.name;
  bool _isImpulsive = false;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = TransactionCategories.expenseNames;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense == null) return;
    _amountController.text = expense.amount.toStringAsFixed(2);
    _descriptionController.text = expense.description;
    _selectedCategory = _categories.contains(expense.category)
        ? expense.category
        : TransactionCategories.expense.last.name;
    _selectedDate = expense.date;
    _isImpulsive = expense.isImpulsive;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _firebaseService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final expense = Expense(
        id: widget.expense?.id,
        userId: user.uid,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        isImpulsive: _isImpulsive,
      );

      final saved = widget.expense == null
          ? await _transactionService.createExpense(expense) != null
          : await _transactionService.updateExpense(expense);
      if (!saved) throw Exception('No se pudo guardar el gasto');
      if (widget.expense == null) {
        unawaited(_postSaveTasks(user.uid, expense.amount));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null ? 'Gasto registrado' : 'Gasto actualizado',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _postSaveTasks(String userId, double amount) async {
    await _gamificationService.onTransactionRegistered(userId, isExpense: true);

    try {
      final budgetStatus = await _budgetService.getBudgetStatus(userId);
      if (budgetStatus['hasBudget'] == true) {
        final remaining = (budgetStatus['remaining'] ?? 0).toDouble();
        final progress = (budgetStatus['percentageUsed'] ?? 0).toDouble();
        final limit = (budgetStatus['totalLimit'] ?? 1).toDouble();

        if (remaining < 0) {
          await _notificationService.showNotification(
            id: 999,
            title: '¡Alerta de Presupuesto!',
            body:
                'Te has excedido en \$${remaining.abs().toStringAsFixed(2)}. Revisa tus finanzas.',
          );
        } else if (progress > 80 && (progress - (amount / limit * 100)) <= 80) {
          await _notificationService.showNotification(
            id: 998,
            title: 'Cuidado con tus gastos',
            body:
                'Ya has consumido el ${progress.toStringAsFixed(0)}% de tu presupuesto mensual.',
          );
        }
      }

      if (amount > 100) {
        await _notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Gasto Considerable',
          body:
              'Has registrado un gasto de \$${amount.toStringAsFixed(2)}. ¿Fue una compra planificada?',
        );
      }
    } catch (e) {
      print('Error en notificaciones de presupuesto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Agregar Gasto' : 'Editar Gasto'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount Input
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monto del Gasto',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          '\$',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            autofillHints: null,
                            enableInteractiveSelection: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            cursorColor: Colors.white,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              fillColor: Colors.transparent,
                              filled: false,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa el monto';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null ||
                                  !amount.isFinite ||
                                  amount <= 0) {
                                return 'Monto inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category Selection
              const Text(
                'Categoría',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Icon(
                              TransactionCategories.expenseInfo(category).icon,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedCategory = newValue);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Date Selection
              const Text(
                'Fecha',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Description Input
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe tu gasto (opcional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Impulsive Checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isImpulsive
                      ? AppTheme.accentColor.withValues(alpha: 0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isImpulsive
                        ? AppTheme.accentColor
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isImpulsive,
                      onChanged: (value) {
                        setState(() => _isImpulsive = value ?? false);
                      },
                      activeColor: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gasto Impulsivo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Marca si fue una compra no planificada',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Guardar Gasto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
