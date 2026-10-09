import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/constants/transaction_categories.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/expense_model.dart';
import '../../../../models/income_model.dart';
import '../../../achievements/data/gamification_service.dart';
import '../../data/local_transaction_parser.dart';
import '../../data/transaction_draft.dart';
import '../../data/transaction_extraction_service.dart';
import '../../data/transaction_service.dart';
import '../../data/category_service.dart';
import '../pages/add_expense_page.dart';
import '../pages/add_income_page.dart';
import '../../../achievements/presentation/widgets/reward_feedback.dart';

class QuickAddResult {
  final bool isExpense;
  final double amount;
  final DateTime date;
  final RewardResult? reward;

  QuickAddResult({
    required this.isExpense,
    required this.amount,
    required this.date,
    this.reward,
  });
}

class QuickAddSheet extends StatefulWidget {
  final bool initialIsExpense;

  /// Categorías de gasto ordenadas por uso (más usada primero). Las que
  /// falten se agregan al final en el orden por defecto.
  final List<String> expenseCategoryOrder;

  const QuickAddSheet({
    super.key,
    this.initialIsExpense = true,
    this.expenseCategoryOrder = const [],
  });

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amountController = TextEditingController();
  final _smartController = TextEditingController();
  final _transactionService = TransactionService();
  final _categoryService = CategoryService();
  final _gamificationService = GamificationService();
  final _firebaseService = FirebaseService();
  final _extractionService = TransactionExtractionService();
  final _speech = SpeechToText();

  late bool _isExpense;
  late String _selectedCategory;
  String _description = '';
  DateTime _date = DateTime.now();
  String? _error;
  String? _smartMessage;
  bool _isInterpreting = false;
  bool _isListening = false;
  bool _isSaving = false;
  List<String> _expenseCategories = TransactionCategories.expenseNames;
  List<String> _incomeCategories = TransactionCategories.incomeNames;

  List<String> get _expenseOptions {
    final defaults = _expenseCategories;
    final ordered = widget.expenseCategoryOrder
        .where(defaults.contains)
        .toList();
    return [...ordered, ...defaults.where((c) => !ordered.contains(c))];
  }

  List<String> get _options => _isExpense ? _expenseOptions : _incomeCategories;

  Color get _modeColor =>
      _isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

  CategoryInfo _infoOf(String name) => _isExpense
      ? TransactionCategories.expenseInfo(name)
      : TransactionCategories.incomeInfo(name);

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _isExpense = widget.initialIsExpense;
    _selectedCategory = _options.first;
    unawaited(_loadCategories());
  }

  Future<void> _loadCategories() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    try {
      final categories = await Future.wait([
        _categoryService.getCategories(
          user.uid,
          TransactionCategoryType.expense,
        ),
        _categoryService.getCategories(
          user.uid,
          TransactionCategoryType.income,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _expenseCategories = categories[0];
        _incomeCategories = categories[1];
        if (!_options.contains(_selectedCategory)) {
          _selectedCategory = _options.first;
        }
      });
    } catch (error) {
      print('Error cargando categorías para registro rápido: $error');
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _amountController.dispose();
    _smartController.dispose();
    super.dispose();
  }

  void _setMode(bool isExpense) {
    setState(() {
      _isExpense = isExpense;
      _selectedCategory = _options.first;
      _error = null;
    });
  }

  void _applyDraft(TransactionDraft draft, String message) {
    setState(() {
      _isExpense = draft.isExpense;
      final category = draft.category;
      _selectedCategory = category != null && _options.contains(category)
          ? category
          : _options.first;
      if (draft.amount != null) {
        _amountController.text = draft.amount!.toStringAsFixed(2);
      }
      _description = draft.description;
      _date = draft.date;
      _error = null;
      _smartMessage = message;
    });
  }

  Future<void> _interpretText(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isInterpreting) return;

    final local = LocalTransactionParser.parse(
      input,
      expenseCategories: _expenseOptions,
      incomeCategories: _incomeCategories,
    );
    if (local.isComplete || !LocalTransactionParser.hasWords(input)) {
      _applyDraft(local, 'Revisa los datos y toca Guardar');
      return;
    }

    setState(() {
      _isInterpreting = true;
      _smartMessage = 'Interpretando…';
    });
    final aiDraft = await _extractionService.fromText(
      input,
      expenseCategories: _expenseOptions,
      incomeCategories: _incomeCategories,
    );
    if (!mounted) return;
    setState(() => _isInterpreting = false);
    _applyDraft(
      aiDraft ?? local,
      aiDraft == null
          ? 'No pude interpretarlo del todo. Completa los datos.'
          : 'Revisa los datos y toca Guardar',
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
    if (!available) {
      setState(() => _smartMessage = 'Reconocimiento de voz no disponible');
      return;
    }
    final locales = await _speech.locales();
    final spanish = locales.where((l) => l.localeId.startsWith('es')).toList();
    if (!mounted) return;
    setState(() {
      _isListening = true;
      _smartMessage = 'Escuchando… di por ejemplo "doce cincuenta almuerzo"';
    });
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: spanish.isEmpty ? null : spanish.first.localeId,
      ),
      onResult: (result) {
        _smartController.text = result.recognizedWords;
        if (result.finalResult) {
          setState(() => _isListening = false);
          _interpretText(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _save() async {
    if (_isSaving || _isInterpreting) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Monto inválido');
      return;
    }

    final user = _firebaseService.currentUser;
    if (user == null) {
      setState(() => _error = 'Inicia sesión para guardar');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    final String? savedId;
    if (_isExpense) {
      final expense = Expense(
        id: null,
        userId: user.uid,
        amount: amount,
        category: _selectedCategory,
        description: _description,
        date: _date,
        isImpulsive: false,
      );
      savedId = await _transactionService.createExpense(expense);
    } else {
      final income = Income(
        id: null,
        userId: user.uid,
        amount: amount,
        source: _selectedCategory,
        description: _description,
        date: _date,
      );
      savedId = await _transactionService.createIncome(income);
    }

    if (savedId == null) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'No se pudo guardar. Intenta de nuevo.';
      });
      return;
    }

    final reward = await confirmReward(
      _gamificationService.onTransactionRegistered(
        user.uid,
        isExpense: _isExpense,
      ),
    );
    unawaited(refreshAchievements(_gamificationService, user.uid));
    if (!mounted) return;

    Navigator.pop(
      context,
      QuickAddResult(
        isExpense: _isExpense,
        amount: amount,
        date: _date,
        reward: reward,
      ),
    );
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

  Widget _buildSmartInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Escribe o dicta un movimiento',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smartController,
          textInputAction: TextInputAction.done,
          onSubmitted: _interpretText,
          maxLines: 1,
          decoration: const InputDecoration(
            hintText: 'Ej.: Almuerzo 12,50 ayer',
            fillColor: AppTheme.backgroundColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isInterpreting
                    ? null
                    : () => _interpretText(_smartController.text),
                icon: _isInterpreting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_isInterpreting ? 'Interpretando' : 'Interpretar'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isInterpreting ? null : _toggleListening,
              icon: Icon(
                _isListening ? Icons.stop_circle : Icons.mic,
                size: 18,
              ),
              label: Text(_isListening ? 'Detener' : 'Dictar'),
            ),
          ],
        ),
        if (_smartMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _smartMessage!,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ],
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
                const SizedBox(height: 16),
                _buildSmartInput(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      showCheckmark: false,
                      label: const Text('Gasto'),
                      selected: _isExpense,
                      selectedColor: AppTheme.expenseColor.withValues(
                        alpha: 0.14,
                      ),
                      labelStyle: TextStyle(
                        color: _isExpense
                            ? AppTheme.expenseColor
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => _setMode(true),
                    ),
                    ChoiceChip(
                      showCheckmark: false,
                      label: const Text('Ingreso'),
                      selected: !_isExpense,
                      selectedColor: AppTheme.incomeColor.withValues(
                        alpha: 0.14,
                      ),
                      labelStyle: TextStyle(
                        color: !_isExpense
                            ? AppTheme.incomeColor
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => _setMode(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
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
                    fillColor: AppTheme.backgroundColor,
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
                if (!_isToday || _description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!_isToday)
                        InputChip(
                          avatar: const Icon(Icons.event, size: 18),
                          label: Text(DateFormat('d MMM', 'es').format(_date)),
                          onDeleted: () =>
                              setState(() => _date = DateTime.now()),
                        ),
                      if (_description.isNotEmpty)
                        InputChip(
                          avatar: const Icon(Icons.notes, size: 18),
                          label: Text(_description),
                          onDeleted: () => setState(() => _description = ''),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('$_isExpense-$_selectedCategory'),
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    fillColor: AppTheme.backgroundColor,
                  ),
                  items: _options.map((option) {
                    final info = _infoOf(option);
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Row(
                        children: [
                          Icon(info.icon, size: 18, color: info.color),
                          const SizedBox(width: 10),
                          Text(option),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (option) {
                    if (option != null) {
                      setState(() => _selectedCategory = option);
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isInterpreting || _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modeColor,
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
