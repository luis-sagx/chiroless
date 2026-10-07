import '../../../../core/constants/transaction_categories.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/income_model.dart';
import '../../../../models/recurring_transaction_model.dart';
import '../../data/transaction_service.dart';
import '../../data/category_service.dart';
import '../../data/recurring_transaction_service.dart';
import '../../../achievements/data/gamification_service.dart';
import '../widgets/recurrence_form_fields.dart';

class AddIncomePage extends StatefulWidget {
  final Income? income;

  const AddIncomePage({Key? key, this.income}) : super(key: key);

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _transactionService = TransactionService();
  final _categoryService = CategoryService();
  final _recurringTransactionService = RecurringTransactionService();
  final _firebaseService = FirebaseService();
  final _gamificationService = GamificationService();

  String _selectedSource = 'Salario';
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  RecurrenceFrequency _recurrenceFrequency = RecurrenceFrequency.monthly;
  DateTime? _recurrenceEndDate;

  List<String> _sources = TransactionCategories.incomeNames;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCategories());
    final income = widget.income;
    if (income == null) return;
    _amountController.text = income.amount.toStringAsFixed(2);
    _descriptionController.text = income.description ?? '';
    if (!_sources.contains(income.source)) _sources.insert(0, income.source);
    _selectedSource = income.source;
    _selectedDate = income.date;
  }

  Future<void> _loadCategories() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    try {
      final categories = await _categoryService.getCategories(
        user.uid,
        TransactionCategoryType.income,
      );
      final historicalSource = widget.income?.source;
      if (historicalSource != null && !categories.contains(historicalSource)) {
        categories.insert(0, historicalSource);
      }
      if (!mounted) return;
      setState(() {
        _sources = categories;
        if (!_sources.contains(_selectedSource))
          _selectedSource = _sources.first;
      });
    } catch (error) {
      print('Error cargando categorías de ingresos: $error');
    }
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
        if (_recurrenceEndDate != null &&
            DateTime(
              _recurrenceEndDate!.year,
              _recurrenceEndDate!.month,
              _recurrenceEndDate!.day,
            ).isBefore(DateTime(picked.year, picked.month, picked.day))) {
          _recurrenceEndDate = null;
        }
      });
    }
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _firebaseService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final income = Income(
        id: widget.income?.id,
        userId: user.uid,
        amount: double.parse(_amountController.text),
        source: _selectedSource,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        recurrenceId: widget.income?.recurrenceId,
        recurrenceDate: widget.income?.recurrenceDate,
      );

      final saved = widget.income == null
          ? await _saveNewIncome(user.uid, income)
          : await _transactionService.updateIncome(income);
      if (!saved) throw Exception('No se pudo guardar el ingreso');
      if (widget.income == null) {
        unawaited(
          _gamificationService.onTransactionRegistered(
            user.uid,
            isExpense: false,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.income == null
                  ? 'Ingreso registrado'
                  : 'Ingreso actualizado',
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

  Future<bool> _saveNewIncome(String userId, Income income) async {
    if (!_isRecurring) {
      return await _transactionService.createIncome(income) != null;
    }
    final seriesId = await _recurringTransactionService.createSeries(
      RecurringTransaction(
        userId: userId,
        isExpense: false,
        amount: income.amount,
        category: income.source,
        startDate: income.date,
        frequency: _recurrenceFrequency,
        endDate: _recurrenceEndDate,
        description: income.description ?? '',
      ),
    );
    if (seriesId == null) return false;
    try {
      await _recurringTransactionService.reconcileForUser(userId);
    } catch (error) {
      // The series is saved; the next app open will retry its due occurrences.
      print('Error registrando primera ocurrencia del ingreso: $error');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.income == null ? 'Agregar Ingreso' : 'Editar Ingreso',
        ),
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
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryColor,
                      AppTheme.secondaryColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monto del Ingreso',
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

              if (widget.income == null) ...[
                const SizedBox(height: 12),
                RecurrenceFormFields(
                  enabled: _isRecurring,
                  frequency: _recurrenceFrequency,
                  startDate: _selectedDate,
                  endDate: _recurrenceEndDate,
                  onEnabledChanged: (value) =>
                      setState(() => _isRecurring = value),
                  onFrequencyChanged: (value) =>
                      setState(() => _recurrenceFrequency = value),
                  onEndDateChanged: (value) =>
                      setState(() => _recurrenceEndDate = value),
                ),
              ] else if (widget.income?.recurrenceId != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Este movimiento pertenece a una serie. Los cambios solo afectan a este movimiento.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],

              const SizedBox(height: 24),

              // Source Selection
              const Text(
                'Fuente de Ingreso',
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
                    value: _selectedSource,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: _sources.map((String source) {
                      return DropdownMenuItem<String>(
                        value: source,
                        child: Row(
                          children: [
                            Icon(
                              TransactionCategories.incomeInfo(source).icon,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(source),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedSource = newValue);
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
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.secondaryColor,
                      ),
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
                  hintText: 'Describe tu ingreso (opcional)',
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
                    borderSide: BorderSide(color: AppTheme.secondaryColor),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.secondaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registrar tus ingresos te ayudará a tener un mejor control de tus finanzas',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveIncome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
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
                        'Guardar Ingreso',
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
