import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/transaction_categories.dart';
import 'transaction_draft.dart';

/// Extrae una transacción desde texto libre o una imagen usando Gemini
/// (Firebase AI Logic). Nunca lanza: devuelve null si algo falla.
class TransactionExtractionService {
  TransactionExtractionService()
    : _model = FirebaseAI.googleAI().generativeModel(
        model: AppConstants.geminiModel,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: _schema,
        ),
      );

  final GenerativeModel _model;

  static final Schema _schema = Schema.object(
    properties: {
      'isExpense': Schema.boolean(),
      'amount': Schema.number(),
      'category': Schema.string(),
      'description': Schema.string(),
      'date': Schema.string(),
    },
    optionalProperties: ['amount', 'description', 'date'],
  );

  Future<TransactionDraft?> fromText(
    String text, {
    List<String>? expenseCategories,
    List<String>? incomeCategories,
  }) {
    final expenses = expenseCategories ?? TransactionCategories.expenseNames;
    final incomes = incomeCategories ?? TransactionCategories.incomeNames;
    final prompt =
        '${_instructions(expenses, incomes)}\n'
        'Al interpretar el monto del texto, convierte centavos a fracciones de '
        'dólar: "50 centavos" = 0.50, "50 dólares" = 50 y "1 dólar con '
        '50 centavos" = 1.50. Un número sin unidad, como "0.5", conserva su '
        'valor decimal. Si se menciona otra moneda (por ejemplo, euros o '
        'pesos), no la conviertas a dólares y omite amount.\n'
        'Texto del usuario: """$text"""';
    return _run([Content.text(prompt)], expenses, incomes);
  }

  Future<TransactionDraft?> fromImage(
    Uint8List bytes,
    String mimeType, {
    List<String>? expenseCategories,
    List<String>? incomeCategories,
  }) {
    final expenses = expenseCategories ?? TransactionCategories.expenseNames;
    final incomes = incomeCategories ?? TransactionCategories.incomeNames;
    final prompt =
        '${_instructions(expenses, incomes)}\n'
        'La imagen es una captura de un comprobante de transferencia, pago, '
        'depósito o recibo. Si el usuario envió o pagó dinero, isExpense es '
        'true; si lo recibió, isExpense es false. Si no se puede saber, usa '
        'isExpense = true. En description NO incluyas números de cuenta, '
        'cédulas ni nombres completos: como máximo el primer nombre de la otra '
        'persona o el nombre del comercio.';
    return _run(
      [
        Content.multi([TextPart(prompt), InlineDataPart(mimeType, bytes)]),
      ],
      expenses,
      incomes,
    );
  }

  String _instructions(List<String> expenses, List<String> incomes) {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'Eres un extractor de transacciones de finanzas personales. '
        'Hoy es $today.\n'
        'Devuelve: isExpense (true = gasto o pago, false = dinero recibido), '
        'amount (número positivo, sin símbolo de moneda, punto decimal), '
        'category (elige SOLO de la lista que corresponda al tipo; si dudas '
        'usa "Otros"), description (máximo 6 palabras, en español), '
        'date (formato YYYY-MM-DD; si no se menciona, usa $today).\n'
        'Categorías de gasto: ${expenses.join(', ')}.\n'
        'Categorías de ingreso: ${incomes.join(', ')}.';
  }

  Future<TransactionDraft?> _run(
    List<Content> content,
    List<String> expenses,
    List<String> incomes,
  ) async {
    try {
      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null) return null;
      final map = jsonDecode(text) as Map<String, dynamic>;
      return _toDraft(map, expenses, incomes);
    } catch (e) {
      print('Error extrayendo transacción: $e');
      return null;
    }
  }

  TransactionDraft _toDraft(
    Map<String, dynamic> map,
    List<String> expenses,
    List<String> incomes,
  ) {
    final isExpense = map['isExpense'] != false;
    final rawAmount = map['amount'];
    final amount = rawAmount is num && rawAmount > 0
        ? rawAmount.toDouble()
        : null;
    final valid = isExpense ? expenses : incomes;
    final rawCategory = map['category'];
    final category = rawCategory is String && valid.contains(rawCategory)
        ? rawCategory
        : valid.isEmpty
        ? 'Otros'
        : valid.first;
    final rawDescription = map['description'];
    return TransactionDraft(
      isExpense: isExpense,
      amount: amount,
      category: category,
      description: rawDescription is String ? rawDescription.trim() : '',
      date: _parseDate(map['date']),
    );
  }

  /// Fecha futura o inválida → ahora. Hoy → ahora (con hora real).
  /// Otro día → ese día a las 12:00.
  DateTime _parseDate(Object? raw) {
    final now = DateTime.now();
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null || parsed.isAfter(now)) return now;
    if (parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day) {
      return now;
    }
    return DateTime(parsed.year, parsed.month, parsed.day, 12);
  }
}
