import 'package:cloud_firestore/cloud_firestore.dart';

class Income {
  final String? id;
  final String userId;
  final double amount;
  final String source;
  final DateTime date;
  final String month; // Formato: "2026-01"
  final String? description;
  final String? recurrenceId;
  final String? recurrenceDate;

  Income({
    this.id,
    required this.userId,
    required this.amount,
    required this.source,
    required this.date,
    String? month,
    this.description,
    this.recurrenceId,
    this.recurrenceDate,
  }) : month = month ?? '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'source': source,
      'date': Timestamp.fromDate(date),
      'month': month,
      if (description != null) 'description': description,
      if (recurrenceId != null) 'recurrenceId': recurrenceId,
      if (recurrenceDate != null) 'recurrenceDate': recurrenceDate,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map, String id) {
    final date = (map['date'] as Timestamp).toDate();
    return Income(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      source: map['source'] ?? '',
      date: date,
      month:
          map['month'] ??
          '${date.year}-${date.month.toString().padLeft(2, '0')}',
      description: map['description'],
      recurrenceId: map['recurrenceId'],
      recurrenceDate: map['recurrenceDate'],
    );
  }

  Income copyWith({
    String? id,
    String? userId,
    double? amount,
    String? source,
    DateTime? date,
    String? month,
    String? description,
    String? recurrenceId,
    String? recurrenceDate,
  }) {
    return Income(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      source: source ?? this.source,
      date: date ?? this.date,
      month: month ?? (date == null ? this.month : null),
      description: description ?? this.description,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      recurrenceDate: recurrenceDate ?? this.recurrenceDate,
    );
  }
}
