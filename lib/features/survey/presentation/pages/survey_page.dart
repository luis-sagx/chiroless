import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/survey_response_model.dart';
import '../../../../core/services/firebase_service.dart';
import '../../data/survey_service.dart';
import '../../../home/presentation/pages/home_page.dart';

class SurveyPage extends StatefulWidget {
  final String surveyType; // 'PRE' o 'POST'

  const SurveyPage({Key? key, required this.surveyType}) : super(key: key);

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final _formKey = GlobalKey<FormState>();
  final _surveyService = SurveyService();
  final _firebaseService = FirebaseService();

  bool _isLoading = false;

  // Datos de control (solo PRE)
  final _careerController = TextEditingController();
  int? _semester;
  bool? _hasOwnIncome;

  // Respuestas (1-5 escala Likert)
  int? _knowledgeIncomeExpenses;
  int? _knowledgeBudget;
  int? _knowledgeDecisions;
  int? _knowledgeSavings;

  int? _savingsConsistency;
  int? _savingsConsideration;
  int? _savingsAllocation;
  int? _savingsGoals;

  int? _trackingOrganization;
  int? _trackingFrequency;
  int? _trackingCategories;
  int? _trackingAwareness;

  int? _selfRegulationPlanning;
  int? _selfRegulationEvaluation;
  int? _selfRegulationAdjustment;
  int? _selfRegulationImprovement;

  int? _toolsPerception;
  int? _toolsEaseOfUse;
  int? _toolsInfluence;
  int? _toolsMotivation;

  @override
  void dispose() {
    _careerController.dispose();
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validar que todas las preguntas estén respondidas
    if (!_areAllQuestionsAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor responde todas las preguntas'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _firebaseService.currentUser!.uid;
      final surveyId = const Uuid().v4();

      final response = SurveyResponse(
        id: surveyId,
        userId: userId,
        type: widget.surveyType,
        completedAt: DateTime.now(),
        career: widget.surveyType == 'PRE'
            ? _careerController.text.trim()
            : null,
        semester: widget.surveyType == 'PRE' ? _semester : null,
        hasOwnIncome: widget.surveyType == 'PRE' ? _hasOwnIncome : null,
        knowledgeIncomeExpenses: _knowledgeIncomeExpenses!,
        knowledgeBudget: _knowledgeBudget!,
        knowledgeDecisions: _knowledgeDecisions!,
        knowledgeSavings: _knowledgeSavings!,
        savingsConsistency: _savingsConsistency!,
        savingsConsideration: _savingsConsideration!,
        savingsAllocation: _savingsAllocation!,
        savingsGoals: _savingsGoals!,
        trackingOrganization: _trackingOrganization!,
        trackingFrequency: _trackingFrequency!,
        trackingCategories: _trackingCategories!,
        trackingAwareness: _trackingAwareness!,
        selfRegulationPlanning: _selfRegulationPlanning!,
        selfRegulationEvaluation: _selfRegulationEvaluation!,
        selfRegulationAdjustment: _selfRegulationAdjustment!,
        selfRegulationImprovement: _selfRegulationImprovement!,
        toolsPerception: _toolsPerception!,
        toolsEaseOfUse: _toolsEaseOfUse!,
        toolsInfluence: _toolsInfluence!,
        toolsMotivation: _toolsMotivation!,
      );

      await _surveyService.saveSurveyResponse(response);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.surveyType == 'PRE'
                  ? '¡Encuesta inicial completada! Ahora puedes usar la app.'
                  : '¡Encuesta final completada! Gracias por tu participación.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Redirigir a HomePage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar encuesta: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _areAllQuestionsAnswered() {
    // Validar datos de control si es PRE
    if (widget.surveyType == 'PRE') {
      if (_careerController.text.trim().isEmpty ||
          _semester == null ||
          _hasOwnIncome == null) {
        return false;
      }
    }

    // Validar todas las dimensiones
    return _knowledgeIncomeExpenses != null &&
        _knowledgeBudget != null &&
        _knowledgeDecisions != null &&
        _knowledgeSavings != null &&
        _savingsConsistency != null &&
        _savingsConsideration != null &&
        _savingsAllocation != null &&
        _savingsGoals != null &&
        _trackingOrganization != null &&
        _trackingFrequency != null &&
        _trackingCategories != null &&
        _trackingAwareness != null &&
        _selfRegulationPlanning != null &&
        _selfRegulationEvaluation != null &&
        _selfRegulationAdjustment != null &&
        _selfRegulationImprovement != null &&
        _toolsPerception != null &&
        _toolsEaseOfUse != null &&
        _toolsInfluence != null &&
        _toolsMotivation != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.surveyType == 'PRE' ? 'Encuesta Inicial' : 'Encuesta Final',
        ),
        automaticallyImplyLeading: widget.surveyType == 'POST',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.assignment, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      widget.surveyType == 'PRE'
                          ? 'Antes de comenzar...'
                          : '¡Ya casi terminamos!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.surveyType == 'PRE'
                          ? 'Responde estas preguntas sobre tus hábitos financieros actuales'
                          : 'Responde estas preguntas sobre cómo ha cambiado tu relación con las finanzas',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Datos de control (solo en PRE)
              if (widget.surveyType == 'PRE') ...[
                _buildSectionTitle('Datos académicos'),
                const SizedBox(height: 16),
                _buildTextInput(
                  controller: _careerController,
                  label: 'Carrera que estudias',
                  hint: 'Ej: Ingeniería en Software',
                ),
                const SizedBox(height: 16),
                _buildSemesterSelector(),
                const SizedBox(height: 16),
                _buildIncomeSelector(),
                const SizedBox(height: 32),
              ],

              // Dimensión 1
              _buildDimension(
                title: 'Conocimiento financiero percibido',
                questions: [
                  _buildQuestion(
                    'Comprendo claramente la diferencia entre ingresos, gastos y ahorro',
                    _knowledgeIncomeExpenses,
                    (v) => setState(() => _knowledgeIncomeExpenses = v),
                  ),
                  _buildQuestion(
                    'Sé cómo elaborar y mantener un presupuesto personal',
                    _knowledgeBudget,
                    (v) => setState(() => _knowledgeBudget = v),
                  ),
                  _buildQuestion(
                    'Tengo conocimientos suficientes para tomar decisiones financieras responsables',
                    _knowledgeDecisions,
                    (v) => setState(() => _knowledgeDecisions = v),
                  ),
                  _buildQuestion(
                    'Entiendo la importancia del ahorro para metas a corto y largo plazo',
                    _knowledgeSavings,
                    (v) => setState(() => _knowledgeSavings = v),
                  ),
                ],
              ),

              // Dimensión 2
              _buildDimension(
                title: 'Hábitos de ahorro',
                questions: [
                  _buildQuestion(
                    'Ahorro dinero de forma constante cada mes',
                    _savingsConsistency,
                    (v) => setState(() => _savingsConsistency = v),
                  ),
                  _buildQuestion(
                    'Antes de gastar, considero si el gasto es realmente necesario',
                    _savingsConsideration,
                    (v) => setState(() => _savingsConsideration = v),
                  ),
                  _buildQuestion(
                    'Suelo destinar una parte de mis ingresos al ahorro',
                    _savingsAllocation,
                    (v) => setState(() => _savingsAllocation = v),
                  ),
                  _buildQuestion(
                    'Tengo metas de ahorro definidas',
                    _savingsGoals,
                    (v) => setState(() => _savingsGoals = v),
                  ),
                ],
              ),

              // Dimensión 3
              _buildDimension(
                title: 'Control y seguimiento de gastos',
                questions: [
                  _buildQuestion(
                    'Registro mis gastos de forma organizada',
                    _trackingOrganization,
                    (v) => setState(() => _trackingOrganization = v),
                  ),
                  _buildQuestion(
                    'Reviso con frecuencia en qué gasto mi dinero',
                    _trackingFrequency,
                    (v) => setState(() => _trackingFrequency = v),
                  ),
                  _buildQuestion(
                    'Conozco exactamente cuánto gasto en categorías como alimentación, transporte u ocio',
                    _trackingCategories,
                    (v) => setState(() => _trackingCategories = v),
                  ),
                  _buildQuestion(
                    'Me doy cuenta rápidamente cuando gasto más de lo que debería',
                    _trackingAwareness,
                    (v) => setState(() => _trackingAwareness = v),
                  ),
                ],
              ),

              // Dimensión 4
              _buildDimension(
                title: 'Autorregulación financiera',
                questions: [
                  _buildQuestion(
                    'Planifico mis gastos antes de realizar compras importantes',
                    _selfRegulationPlanning,
                    (v) => setState(() => _selfRegulationPlanning = v),
                  ),
                  _buildQuestion(
                    'Evalúo mis decisiones financieras después de gastar',
                    _selfRegulationEvaluation,
                    (v) => setState(() => _selfRegulationEvaluation = v),
                  ),
                  _buildQuestion(
                    'Ajusto mis hábitos financieros cuando noto errores',
                    _selfRegulationAdjustment,
                    (v) => setState(() => _selfRegulationAdjustment = v),
                  ),
                  _buildQuestion(
                    'Me esfuerzo por mejorar mi comportamiento financiero con el tiempo',
                    _selfRegulationImprovement,
                    (v) => setState(() => _selfRegulationImprovement = v),
                  ),
                ],
              ),

              // Dimensión 5
              _buildDimension(
                title: 'Uso de herramientas digitales',
                questions: [
                  _buildQuestion(
                    'Considero que las herramientas digitales pueden ayudarme a mejorar mis hábitos financieros',
                    _toolsPerception,
                    (v) => setState(() => _toolsPerception = v),
                  ),
                  _buildQuestion(
                    'Me resulta fácil usar aplicaciones para controlar mis finanzas personales',
                    _toolsEaseOfUse,
                    (v) => setState(() => _toolsEaseOfUse = v),
                  ),
                  _buildQuestion(
                    'Las aplicaciones financieras influyen positivamente en mis decisiones económicas',
                    _toolsInfluence,
                    (v) => setState(() => _toolsInfluence = v),
                  ),
                  _buildQuestion(
                    'Me siento motivado a ahorrar cuando utilizo herramientas digitales de control financiero',
                    _toolsMotivation,
                    (v) => setState(() => _toolsMotivation = v),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Botón enviar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.surveyType == 'PRE'
                              ? 'Comenzar a usar la app'
                              : 'Enviar encuesta final',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Este campo es obligatorio';
        }
        return null;
      },
    );
  }

  Widget _buildSemesterSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Semestre que cursas',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(10, (index) {
            final semester = index + 1;
            return ChoiceChip(
              label: Text('$semester'),
              selected: _semester == semester,
              onSelected: (selected) {
                setState(() => _semester = selected ? semester : null);
              },
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: _semester == semester ? Colors.white : Colors.black,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildIncomeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Recibes ingresos propios?',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Sí'),
                value: true,
                groupValue: _hasOwnIncome,
                onChanged: (value) => setState(() => _hasOwnIncome = value),
                activeColor: AppTheme.primaryColor,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('No'),
                value: false,
                groupValue: _hasOwnIncome,
                onChanged: (value) => setState(() => _hasOwnIncome = value),
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDimension({
    required String title,
    required List<Widget> questions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 16),
        ...questions,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuestion(
    String question,
    int? currentValue,
    ValueChanged<int> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Totalmente\nen desacuerdo',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const Expanded(
                child: Text(
                  'Totalmente\nde acuerdo',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Radio<int>(
                      value: value,
                      groupValue: currentValue,
                      onChanged: (v) => onChanged(v!),
                      activeColor: AppTheme.primaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
