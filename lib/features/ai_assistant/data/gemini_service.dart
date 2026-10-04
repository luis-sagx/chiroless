import 'package:firebase_ai/firebase_ai.dart';
import '../../../core/constants/app_constants.dart';

/// Servicio para interactuar con Google Gemini AI
class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: AppConstants.geminiModel,
    );
  }

  /// Obtener consejos financieros personalizados
  Future<String> getFinancialAdvice({
    required double totalIncome,
    required double totalExpenses,
    required double savingsPercentage,
    String? additionalContext,
  }) async {
    try {
      final prompt =
          '''
Eres un asesor financiero experto. Proporciona consejos breves y prácticos en español.

Situación financiera del usuario:
- Ingresos totales: \$${totalIncome.toStringAsFixed(2)}
- Gastos totales: \$${totalExpenses.toStringAsFixed(2)}
- Porcentaje de ahorro: ${savingsPercentage.toStringAsFixed(1)}%
${additionalContext != null ? '- Contexto adicional: $additionalContext' : ''}

Por favor proporciona:
1. Una evaluación breve de su salud financiera
2. 2-3 consejos específicos y accionables
3. Una meta financiera sugerida

Mantén la respuesta en menos de 200 palabras.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'No se pudo generar un consejo en este momento.';
    } catch (e) {
      print('Error obteniendo consejo financiero: $e');
      return 'Error al conectar con el asistente de IA. Intenta más tarde.';
    }
  }

  /// Analizar un gasto y sugerir si es necesario o impulsivo
  Future<Map<String, dynamic>> analyzeExpense({
    required String category,
    required double amount,
    required String description,
  }) async {
    try {
      final prompt =
          '''
Analiza el siguiente gasto y determina si es necesario o impulsivo:

Categoría: $category
Monto: \$$amount
Descripción: $description

Responde ÚNICAMENTE con un JSON en este formato exacto:
{
  "isImpulsive": true o false,
  "reason": "razón breve en español (máximo 50 palabras)"
}
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final text =
          response.text ??
          '{"isImpulsive": false, "reason": "No se pudo analizar"}';

      // Intentar extraer JSON de la respuesta
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        // Parsear manualmente para evitar problemas con formato
        final isImpulsive = jsonStr.contains('"isImpulsive": true');
        final reasonMatch = RegExp(
          r'"reason":\s*"([^"]*)"',
        ).firstMatch(jsonStr);
        final reason = reasonMatch?.group(1) ?? 'Análisis no disponible';

        return {'isImpulsive': isImpulsive, 'reason': reason};
      }

      return {'isImpulsive': false, 'reason': 'No se pudo analizar el gasto'};
    } catch (e) {
      print('Error analizando gasto: $e');
      return {'isImpulsive': false, 'reason': 'Error al analizar'};
    }
  }

  /// Obtener sugerencias de presupuesto basadas en ingresos
  Future<String> suggestBudget({
    required double monthlyIncome,
    required Map<String, double> currentExpensesByCategory,
  }) async {
    try {
      final categoriesStr = currentExpensesByCategory.entries
          .map((e) => '- ${e.key}: \$${e.value.toStringAsFixed(2)}')
          .join('\n');

      final prompt =
          '''
Sugiere un presupuesto mensual realista en español para alguien con:
- Ingreso mensual: \$${monthlyIncome.toStringAsFixed(2)}

Gastos actuales por categoría:
$categoriesStr

Proporciona:
1. Presupuesto sugerido siguiendo la regla 50/30/20 (necesidades/deseos/ahorros)
2. Límites específicos por categoría
3. Un consejo final

Respuesta en menos de 150 palabras.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'No se pudo generar una sugerencia.';
    } catch (e) {
      print('Error sugiriendo presupuesto: $e');
      return 'Error al generar sugerencia de presupuesto.';
    }
  }

  /// Chat general sobre finanzas
  Future<String> chat(String userMessage) async {
    try {
      final prompt =
          '''
Eres un asistente financiero amigable. Responde en español de forma breve y útil.

Usuario: $userMessage

Asistente:
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'Lo siento, no pude procesar tu mensaje.';
    } catch (e) {
      print('Error en chat: $e');
      return 'Error al procesar tu mensaje.';
    }
  }
}
