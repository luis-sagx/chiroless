import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
import '../pages/add_expense_page.dart';
import '../pages/add_income_page.dart';

class QuickAddResult {
  final bool isExpense;
  final double amount;
  final DateTime date;

  QuickAddResult({
    required this.isExpense,
    required this.amount,
    required this.date,
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
  final _gamificationService = GamificationService();
  final _firebaseService = FirebaseService();
  final _extractionService = TransactionExtractionService();
  final _speech = SpeechToText();
  final _imagePicker = ImagePicker();

  late bool _isExpense;
  late String _selectedCategory;
  String _description = '';
  DateTime _date = DateTime.now();
  String? _error;
  String? _smartMessage;
  bool _isInterpreting = false;
  bool _isListening = false;
  bool _isSaving = false;

  List<String> get _expenseOptions {
    final defaults = TransactionCategories.expenseNames;
    final ordered = widget.expenseCategoryOrder
        .where(defaults.contains)
        .toList();
    return [...ordered, ...defaults.where((c) => !ordered.contains(c))];
  }

  List<String> get _options =>
      _isExpense ? _expenseOptions : TransactionCategories.incomeNames;

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

    final local = LocalTransactionParser.parse(input);
    if (local.isComplete || !LocalTransactionParser.hasWords(input)) {
      _applyDraft(local, 'Revisa los datos y toca Guardar');
      return;
    }

    setState(() {
      _isInterpreting = true;
      _smartMessage = 'Interpretando…';
    });
    final aiDraft = await _extractionService.fromText(input);
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

  Future<void> _pickImage(ImageSource source) async {
    if (_isInterpreting) return;
    final XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 70,
      );
    } catch (e) {
      setState(() => _smartMessage = 'No se pudo abrir la imagen');
      return;
    }
    if (image == null || !mounted) return;

    setState(() {
      _isInterpreting = true;
      _smartMessage = 'Leyendo comprobante…';
    });
    final bytes = await image.readAsBytes();
    final mimeType =
        image.mimeType ??
        (image.path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg');
    final draft = await _extractionService.fromImage(bytes, mimeType);
    if (!mounted) return;
    setState(() => _isInterpreting = false);
    if (draft == null) {
      setState(
        () => _smartMessage =
            'No pude leer el comprobante. Ingresa los datos a mano.',
      );
      return;
    }
    _applyDraft(draft, 'Revisa los datos y toca Guardar');
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

    if (!mounted) return;
    if (savedId == null) {
      setState(() {
        _isSaving = false;
        _error = 'No se pudo guardar. Intenta de nuevo.';
      });
      return;
    }

    if (_isExpense) {
      unawaited(
        _gamificationService.onTransactionRegistered(user.uid, isExpense: true),
      );
    } else {
      unawaited(
        _gamificationService.onTransactionRegistered(
          user.uid,
          isExpense: false,
        ),
      );
    }

    Navigator.pop(
      context,
      QuickAddResult(isExpense: _isExpense, amount: amount, date: _date),
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _smartController,
                textInputAction: TextInputAction.done,
                onSubmitted: _interpretText,
                decoration: InputDecoration(
                  hintText: 'Ej: 12.50 almuerzo ayer',
                  fillColor: AppTheme.backgroundColor,
                  prefixIcon: const Icon(Icons.auto_awesome),
                  suffixIcon: _isInterpreting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () =>
                              _interpretText(_smartController.text),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Dictar',
              onPressed: _isInterpreting ? null : _toggleListening,
              icon: Icon(
                _isListening ? Icons.stop_circle : Icons.mic,
                color: _isListening ? AppTheme.expenseColor : null,
              ),
            ),
            PopupMenuButton<ImageSource>(
              tooltip: 'Leer comprobante',
              enabled: !_isInterpreting,
              icon: const Icon(Icons.photo_camera_outlined),
              onSelected: _pickImage,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ImageSource.gallery,
                  child: Text('Captura de la galería'),
                ),
                PopupMenuItem(
                  value: ImageSource.camera,
                  child: Text('Tomar foto'),
                ),
              ],
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _options.map((option) {
                    final selected = option == _selectedCategory;
                    final info = _infoOf(option);
                    return ChoiceChip(
                      avatar: Icon(
                        info.icon,
                        size: 18,
                        color: selected ? info.color : AppTheme.textSecondary,
                      ),
                      label: Text(option),
                      selected: selected,
                      selectedColor: info.color.withValues(alpha: 0.14),
                      labelStyle: TextStyle(
                        color: selected ? info.color : Colors.grey.shade700,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
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
