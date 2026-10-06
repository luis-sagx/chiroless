import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String userId;
  final double amount;
  final String category;
  final DateTime date;
  final String month; // Formato: "2026-01"
  final String description;
  final bool isImpulsive; // Indicador de gasto impulsivo

  Expense({
    this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.date,
    String? month,
    required this.description,
    this.isImpulsive = false,
  }) : month = month ?? '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'month': month,
      'description': description,
      'isImpulsive': isImpulsive,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map, String id) {
    final date = (map['date'] as Timestamp).toDate();
    return Expense(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      date: date,
      month:
          map['month'] ??
          '${date.year}-${date.month.toString().padLeft(2, '0')}',
      description: map['description'] ?? '',
      isImpulsive: map['isImpulsive'] ?? false,
    );
  }

  Expense copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    DateTime? date,
    String? month,
    String? description,
    bool? isImpulsive,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      month: month ?? (date == null ? this.month : null),
      description: description ?? this.description,
      isImpulsive: isImpulsive ?? this.isImpulsive,
    );
  }
}
