import 'package:flutter/material.dart';

/// Nombre, ícono y color de una categoría de gasto o fuente de ingreso.
class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo(this.name, this.icon, this.color);
}

/// Única fuente de verdad de categorías. Los nombres coinciden con los
/// guardados en Firestore: NO los cambies o se pierde el historial.
class TransactionCategories {
  TransactionCategories._();

  static const List<CategoryInfo> expense = [
    CategoryInfo('Alimentación', Icons.restaurant, Color(0xFFF97316)),
    CategoryInfo('Transporte', Icons.directions_bus, Color(0xFF3B82F6)),
    CategoryInfo('Entretenimiento', Icons.movie, Color(0xFFA855F7)),
    CategoryInfo('Salud', Icons.medical_services, Color(0xFFEF4444)),
    CategoryInfo('Educación', Icons.school, Color(0xFF14B8A6)),
    CategoryInfo('Vivienda', Icons.home, Color(0xFF6366F1)),
    CategoryInfo('Ropa', Icons.shopping_bag, Color(0xFFEC4899)),
    CategoryInfo('Servicios', Icons.build, Color(0xFFEAB308)),
    CategoryInfo('Otros', Icons.more_horiz, Color(0xFF9CA3AF)),
  ];

  static const List<CategoryInfo> income = [
    CategoryInfo('Salario', Icons.work, Color(0xFF16A34A)),
    CategoryInfo('Freelance', Icons.laptop, Color(0xFF0EA5E9)),
    CategoryInfo('Negocio', Icons.business, Color(0xFF6366F1)),
    CategoryInfo('Inversiones', Icons.trending_up, Color(0xFF14B8A6)),
    CategoryInfo('Regalo', Icons.card_giftcard, Color(0xFFEC4899)),
    CategoryInfo('Beca', Icons.school, Color(0xFFF59E0B)),
    CategoryInfo('Padres', Icons.family_restroom, Color(0xFFF97316)),
    CategoryInfo('Otros', Icons.more_horiz, Color(0xFF9CA3AF)),
  ];

  static List<String> get expenseNames => expense.map((c) => c.name).toList();

  static List<String> get incomeNames => income.map((c) => c.name).toList();

  /// Gives user-created categories a stable visual identity without changing
  /// their stored name (which is also the historical transaction value).
  static CategoryInfo expenseInfo(String name) => _info(expense, name);

  static CategoryInfo incomeInfo(String name) => _info(income, name);

  static CategoryInfo _info(List<CategoryInfo> defaults, String name) {
    final existing = defaults.where((category) => category.name == name);
    if (existing.isNotEmpty) return existing.first;
    var stableHash = 0;
    for (final rune in name.runes) {
      stableHash = (stableHash * 31 + rune) & 0x7fffffff;
    }
    final index = stableHash % defaults.length;
    final fallback = defaults[index];
    return CategoryInfo(name, fallback.icon, fallback.color);
  }
}
