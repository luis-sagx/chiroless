import 'transaction_draft.dart';
import '../../../core/constants/transaction_categories.dart';

/// Interpreta frases cortas ("12.50 almuerzo ayer") sin red ni IA.
/// ponytail: diccionario fijo de palabras clave y el primer número es el monto;
/// si no alcanza, el QuickAddSheet recurre a Gemini (Fase 4).
class LocalTransactionParser {
  LocalTransactionParser._();

  // Grupo 1: parte entera (con separadores de miles opcionales).
  // Grupo 2: 1-2 decimales tras punto o coma.
  static final RegExp _amountPattern = RegExp(
    r'(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](\d{1,2}))?(?!\d)',
  );
  static final RegExp _wordSplit = RegExp(r'[^a-záéíóúñü]+');

  static const Set<String> _dollarUnits = {
    'dólar', 'dólares', 'dolar', 'dolares', 'usd',
  };
  static const Set<String> _centUnits = {'centavo', 'centavos'};
  static const Set<String> _otherCurrencyUnits = {
    'euro', 'euros', 'peso', 'pesos', 'sol', 'soles', 'libra', 'libras',
    'yen', 'yenes', 'franco', 'francos', 'real', 'reales', 'rublo', 'rublos',
    'yuan', 'yuanes', 'won', 'colón', 'colones', 'bolívar', 'bolívares',
    'bolivar', 'bolivares',
  };

  static const Set<String> _dateWords = {'hoy', 'ayer', 'anteayer'};

  static const Set<String> _incomeTriggers = {
    'recibí', 'recibi', 'cobré', 'cobre', 'ingreso', 'ingresó',
    'pagaron', 'depositaron', 'transfirieron', 'gané', 'gane',
  };

  static const Set<String> _expenseTriggers = {
    'compré', 'compre', 'pagué', 'pague', 'gasté', 'gaste',
  };

  static const Map<String, List<String>> _expenseKeywords = {
    'Alimentación': [
      'almuerzo', 'desayuno', 'cena', 'comida', 'café', 'cafe',
      'restaurante', 'mercado', 'supermercado', 'súper', 'super', 'pizza',
      'hamburguesa', 'snack', 'pan', 'frutas', 'víveres', 'viveres', 'helado',
    ],
    'Transporte': [
      'uber', 'taxi', 'bus', 'pasaje', 'pasajes', 'gasolina', 'combustible',
      'metro', 'didi', 'indrive', 'indriver', 'parqueadero', 'peaje', 'cabify',
    ],
    'Entretenimiento': [
      'cine', 'netflix', 'spotify', 'juego', 'juegos', 'fiesta', 'concierto',
      'bar', 'discoteca', 'disney', 'salida',
    ],
    'Salud': [
      'farmacia', 'medicina', 'medicinas', 'doctor', 'médico', 'medico',
      'consulta', 'pastillas', 'hospital', 'dentista', 'odontólogo',
    ],
    'Educación': [
      'libro', 'libros', 'curso', 'universidad', 'matrícula', 'matricula',
      'colegio', 'copias', 'útiles', 'utiles', 'pensión', 'pension',
    ],
    'Vivienda': ['arriendo', 'alquiler', 'renta', 'hipoteca'],
    'Ropa': [
      'ropa', 'zapatos', 'camisa', 'camiseta', 'pantalón', 'pantalon',
      'zapatillas', 'vestido', 'chompa',
    ],
    'Servicios': [
      'luz', 'agua', 'internet', 'teléfono', 'telefono', 'celular', 'recarga',
      'gas', 'plan',
    ],
  };

  static const Map<String, List<String>> _incomeKeywords = {
    'Salario': ['salario', 'sueldo', 'quincena', 'nómina', 'nomina'],
    'Freelance': ['freelance', 'proyecto', 'cliente'],
    'Negocio': ['venta', 'ventas', 'vendí', 'vendi', 'negocio'],
    'Inversiones': ['intereses', 'dividendos', 'inversión', 'inversion'],
    'Regalo': ['regalo', 'regalaron'],
    'Beca': ['beca'],
    'Padres': ['papá', 'mamá', 'papi', 'mami', 'padres', 'mesada'],
  };

  static Set<String> _tokens(String text) => text
      .toLowerCase()
      .split(_wordSplit)
      .where((w) => w.isNotEmpty)
      .toSet();

  /// true si el texto tiene alguna palabra (no solo números/símbolos).
  static bool hasWords(String text) => _tokens(text).isNotEmpty;

  static TransactionDraft parse(
    String text, {
    DateTime? now,
    List<String>? expenseCategories,
    List<String>? incomeCategories,
  }) {
    final current = now ?? DateTime.now();
    final tokens = _tokens(text);
    final expenses = expenseCategories ?? TransactionCategories.expenseNames;
    final incomes = incomeCategories ?? TransactionCategories.incomeNames;

    final forcedExpense = tokens.any(_expenseTriggers.contains);
    final isIncome = !forcedExpense &&
        (tokens.any(_incomeTriggers.contains) ||
            _findCategory(tokens, _incomeKeywords) != null ||
            _findNamedCategory(tokens, incomes) != null);
    final category = _findCategory(
      tokens,
      isIncome ? _incomeKeywords : _expenseKeywords,
    ) ?? _findNamedCategory(tokens, isIncome ? incomes : expenses);

    final matches = _amountPattern.allMatches(text).toList();
    final hasOtherCurrency = tokens.any(_otherCurrencyUnits.contains);
    final hasCentUnit = tokens.any(_centUnits.contains);
    double? amount;
    if (!hasOtherCurrency && matches.isNotEmpty) {
      if (hasCentUnit) {
        var dollars = 0.0;
        var cents = 0.0;
        for (var i = 0; i < matches.length; i++) {
          final match = matches[i];
          final end = i + 1 < matches.length
              ? matches[i + 1].start
              : text.length;
          final followingWords = _tokens(text.substring(match.end, end));
          final value = _parseAmount(match);
          if (followingWords.any(_centUnits.contains)) {
            cents += value;
          } else if (followingWords.any(_dollarUnits.contains)) {
            dollars += value;
          }
        }
        amount = dollars + cents / 100;
      } else {
        amount = _parseAmount(matches.first);
      }
    }

    var daysAgo = 0;
    if (tokens.contains('anteayer')) {
      daysAgo = 2;
    } else if (tokens.contains('ayer')) {
      daysAgo = 1;
    }
    final date = daysAgo == 0
        ? current
        : DateTime(
            current.year,
            current.month,
            current.day - daysAgo,
            current.hour,
            current.minute,
          );

    var rest = text;
    if (matches.isNotEmpty && !hasOtherCurrency) {
      for (final match in matches) {
        rest = rest.replaceFirst(match.group(0)!, ' ');
      }
      if (hasCentUnit || tokens.any(_dollarUnits.contains)) {
        rest = rest.replaceAll(
          RegExp(
            r'\b(?:dólares?|dolares?|usd|centavos?)\b',
            caseSensitive: false,
          ),
          ' ',
        );
      }
    }
    final description = rest
        .replaceAll('\$', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_dateWords.contains(w.toLowerCase()))
        .join(' ');

    return TransactionDraft(
      isExpense: !isIncome,
      amount: amount,
      category: category,
      description: description,
      date: date,
    );
  }

  static double _parseAmount(RegExpMatch match) {
    final whole = match.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    final decimals = match.group(2);
    return double.parse(decimals == null ? whole : '$whole.$decimals');
  }

  static String? _findCategory(
    Set<String> tokens,
    Map<String, List<String>> keywords,
  ) {
    for (final entry in keywords.entries) {
      if (entry.value.any(tokens.contains)) return entry.key;
    }
    return null;
  }

  static String? _findNamedCategory(
    Set<String> tokens,
    List<String> categories,
  ) {
    final matches = categories.where((category) {
      final categoryTokens = _tokens(category);
      return categoryTokens.isNotEmpty && categoryTokens.every(tokens.contains);
    }).toList()..sort((a, b) => b.length.compareTo(a.length));
    return matches.isEmpty ? null : matches.first;
  }
}
