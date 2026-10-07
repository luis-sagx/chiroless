import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceFrequency { weekly, monthly, yearly }

class RecurringTransaction {
  const RecurringTransaction({
    this.id,
    required this.userId,
    required this.isExpense,
    required this.amount,
    required this.category,
    required this.startDate,
    required this.frequency,
    this.endDate,
    this.description = '',
    this.isImpulsive = false,
  });

  final String? id;
  final String userId;
  final bool isExpense;
  final double amount;
  final String category;
  final DateTime startDate;
  final RecurrenceFrequency frequency;
  final DateTime? endDate;
  final String description;
  final bool isImpulsive;

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'isExpense': isExpense,
    'amount': amount,
    'category': category,
    'startDate': Timestamp.fromDate(startDate),
    'frequency': frequency.name,
    'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
    'description': description,
    'isImpulsive': isImpulsive,
  };

  factory RecurringTransaction.fromMap(Map<String, dynamic> map, String id) {
    final rawStartDate = map['startDate'];
    final rawEndDate = map['endDate'];
    final frequencyName = map['frequency'] as String?;
    final frequency = RecurrenceFrequency.values.firstWhere(
      (value) => value.name == frequencyName,
      orElse: () => RecurrenceFrequency.monthly,
    );

    return RecurringTransaction(
      id: id,
      userId: map['userId'] as String? ?? '',
      isExpense: map['isExpense'] as bool? ?? true,
      amount: (map['amount'] as num? ?? 0).toDouble(),
      category: map['category'] as String? ?? '',
      startDate: rawStartDate is Timestamp
          ? rawStartDate.toDate()
          : DateTime.now(),
      frequency: frequency,
      endDate: rawEndDate is Timestamp ? rawEndDate.toDate() : null,
      description: map['description'] as String? ?? '',
      isImpulsive: map['isImpulsive'] as bool? ?? false,
    );
  }
}
