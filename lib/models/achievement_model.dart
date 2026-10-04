import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String? id;
  final String userId;
  final String title;
  final String description;
  final String icon; // Nombre del icono
  final int points;
  final DateTime? unlockedAt;
  final String category; // 'streak', 'budget', 'savings', 'milestone'
  final String type; // Type for icon identification

  bool get isUnlocked => unlockedAt != null;

  Achievement({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    this.unlockedAt,
    required this.category,
    this.type = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'icon': icon,
      'points': points,
      'unlockedAt': unlockedAt != null ? Timestamp.fromDate(unlockedAt!) : null,
      'category': category,
      'type': type,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map, String id) {
    return Achievement(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? 'emoji_events',
      points: map['points'] ?? 0,
      unlockedAt: map['unlockedAt'] != null
          ? (map['unlockedAt'] as Timestamp).toDate()
          : null,
      category: map['category'] ?? 'milestone',
      type: map['type'] ?? '',
    );
  }

  Achievement copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? icon,
    int? points,
    DateTime? unlockedAt,
    String? category,
    String? type,
  }) {
    return Achievement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      points: points ?? this.points,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      category: category ?? this.category,
      type: type ?? this.type,
    );
  }
}

// Logros predefinidos del sistema
class AchievementTemplates {
  static const List<Map<String, dynamic>> templates = [
    {
      'title': 'Primera transacción',
      'key': 'first_transaction',
      'description': 'Registraste tu primer gasto o ingreso',
      'icon': 'star',
      'points': 10,
      'category': 'milestone',
    },
    {
      'title': 'Racha de 7 días',
      'key': 'streak_7',
      'description': 'Registraste transacciones durante 7 días consecutivos',
      'icon': 'local_fire_department',
      'points': 50,
      'category': 'streak',
    },
    {
      'title': 'Presupuesto cumplido',
      'key': 'budget_month',
      'description': 'Cerraste un mes sin exceder tu presupuesto',
      'icon': 'check_circle',
      'points': 100,
      'category': 'budget',
    },
    {
      'title': 'Ahorrador novato',
      'key': 'savings_10',
      'description':
          'Ahorraste al menos 10% de tus ingresos del mes (mín. 5 gastos)',
      'icon': 'savings',
      'points': 75,
      'category': 'savings',
    },
    {
      'title': 'Control total',
      'key': 'control_impulse',
      'description':
          'Con 10+ gastos registrados, mantuviste los impulsivos bajo 20%',
      'icon': 'psychology',
      'points': 150,
      'category': 'milestone',
    },
  ];
}
