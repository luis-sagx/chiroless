import 'transaction_draft.dart';

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

  static TransactionDraft parse(String text, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final tokens = _tokens(text);

    final forcedExpense = tokens.any(_expenseTriggers.contains);
    final isIncome = !forcedExpense &&
        (tokens.any(_incomeTriggers.contains) ||
            _findCategory(tokens, _incomeKeywords) != null);
    final category = _findCategory(
      tokens,
      isIncome ? _incomeKeywords : _expenseKeywords,
    );

    final match = _amountPattern.firstMatch(text);
    double? amount;
    if (match != null) {
      final whole = match.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      final decimals = match.group(2);
      amount = double.parse(decimals == null ? whole : '$whole.$decimals');
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
    if (match != null) rest = rest.replaceFirst(match.group(0)!, ' ');
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

  static String? _findCategory(
    Set<String> tokens,
    Map<String, List<String>> keywords,
  ) {
    for (final entry in keywords.entries) {
      if (entry.value.any(tokens.contains)) return entry.key;
    }
    return null;
  }
}
