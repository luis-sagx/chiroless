import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  /// El último cambio vigente; las claves YYYY-MM tienen orden cronológico.
  static Budget? latestForMonth(Iterable<Budget> budgets, String month) {
    Budget? latest;
    for (final budget in budgets) {
      if (budget.month.compareTo(month) > 0) continue;
      if (latest == null || budget.month.compareTo(latest.month) > 0) {
        latest = budget;
      }
    }
    return latest;
  }

  final String? id;
  final String userId;
  final double monthlyLimit;
  final String month; // Formato: "2026-01"
  final Map<String, double>? categoryLimits; // Límites por categoría (opcional)
  final DateTime createdAt;

  Budget({
    this.id,
    required this.userId,
    required this.monthlyLimit,
    required this.month,
    this.categoryLimits,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'monthlyLimit': monthlyLimit,
      'month': month,
      if (categoryLimits != null) 'categoryLimits': categoryLimits,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map, String id) {
    return Budget(
      id: id,
      userId: map['userId'] ?? '',
      monthlyLimit: (map['monthlyLimit'] ?? 0).toDouble(),
      month: map['month'] ?? '',
      categoryLimits: map['categoryLimits'] != null
          ? Map<String, double>.from(map['categoryLimits'])
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Budget copyWith({
    String? id,
    String? userId,
    double? monthlyLimit,
    String? month,
    Map<String, double>? categoryLimits,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      month: month ?? this.month,
      categoryLimits: categoryLimits ?? this.categoryLimits,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Cambiar un límite heredado crea una configuración desde el mes indicado.
  Budget overrideFrom(String targetMonth, {required double monthlyLimit}) {
    return Budget(
      userId: userId,
      monthlyLimit: monthlyLimit,
      month: targetMonth,
      categoryLimits: categoryLimits,
    );
  }
}
