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

  static List<String> get _allCategories => {
    ...TransactionCategories.expenseNames,
    ...TransactionCategories.incomeNames,
  }.toList();

  static final Schema _schema = Schema.object(
    properties: {
      'isExpense': Schema.boolean(),
      'amount': Schema.number(),
      'category': Schema.enumString(enumValues: _allCategories),
      'description': Schema.string(),
      'date': Schema.string(),
    },
    optionalProperties: ['amount', 'description', 'date'],
  );

  Future<TransactionDraft?> fromText(String text) {
    final prompt = '${_instructions()}\nTexto del usuario: """$text"""';
    return _run([Content.text(prompt)]);
  }

  Future<TransactionDraft?> fromImage(Uint8List bytes, String mimeType) {
    final prompt =
        '${_instructions()}\n'
        'La imagen es una captura de un comprobante de transferencia, pago, '
        'depósito o recibo. Si el usuario envió o pagó dinero, isExpense es '
        'true; si lo recibió, isExpense es false. Si no se puede saber, usa '
        'isExpense = true. En description NO incluyas números de cuenta, '
        'cédulas ni nombres completos: como máximo el primer nombre de la otra '
        'persona o el nombre del comercio.';
    return _run([
      Content.multi([TextPart(prompt), InlineDataPart(mimeType, bytes)]),
    ]);
  }

  String _instructions() {
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
        'Categorías de gasto: ${TransactionCategories.expenseNames.join(', ')}.\n'
        'Categorías de ingreso: ${TransactionCategories.incomeNames.join(', ')}.';
  }

  Future<TransactionDraft?> _run(List<Content> content) async {
    try {
      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null) return null;
      final map = jsonDecode(text) as Map<String, dynamic>;
      return _toDraft(map);
    } catch (e) {
      print('Error extrayendo transacción: $e');
      return null;
    }
  }

  TransactionDraft _toDraft(Map<String, dynamic> map) {
    final isExpense = map['isExpense'] != false;
    final rawAmount = map['amount'];
    final amount = rawAmount is num && rawAmount > 0
        ? rawAmount.toDouble()
        : null;
    final valid = isExpense
        ? TransactionCategories.expenseNames
        : TransactionCategories.incomeNames;
    final rawCategory = map['category'];
    final category = rawCategory is String && valid.contains(rawCategory)
        ? rawCategory
        : 'Otros';
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
