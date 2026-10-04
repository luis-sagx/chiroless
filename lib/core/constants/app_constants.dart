class AppConstants {
  // Niveles de usuario (gamificación)
  static const List<String> userLevels = [
    'Principiante',
    'Novato',
    'Organizado',
    'Responsable',
    'Estratégico',
    'Maestro Financiero',
  ];

  // Límites y configuraciones
  static const int minPasswordLength = 6;
  static const int maxDaysForImpulsiveExpense = 0; // Gastos el mismo día
  static const double warningBudgetPercentage = 80.0; // Alerta al 80%
  static const double criticalBudgetPercentage = 95.0; // Crítico al 95%

  // Puntos de experiencia para gamificación
  static const int pointsPerExpenseRegistered = 10;
  static const int pointsPerIncomeRegistered = 15;
  static const int pointsPerBudgetCompliance = 50;
  static const int pointsPerAchievementUnlocked = 100;

  // Modelo de Gemini usado vía Firebase AI Logic (ver Fase 2).
  // Si Firebase responde "model not found", consulta
  // https://firebase.google.com/docs/ai-logic/models y usa el modelo "flash" vigente.
  static const String geminiModel = 'gemini-3.8-flash';
}
