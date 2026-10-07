import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/recurring_transaction_model.dart';

class RecurringTransactionService {
  RecurringTransactionService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _series =>
      _db.collection('recurringTransactions');

  Future<String?> createSeries(RecurringTransaction series) async {
    try {
      final reference = await _series.add(series.toMap());
      return reference.id;
    } catch (error) {
      print('Error creando recurrencia: $error');
      return null;
    }
  }

  /// Creates every due occurrence for this user. Deterministic transaction
  /// IDs make concurrent app opens idempotent, and existing transactions are
  /// left untouched so editing an occurrence never changes its series.
  Future<void> reconcileForUser(String userId, {DateTime? now}) async {
    if (userId.isEmpty) return;
    final today = _dateOnly(now ?? DateTime.now());
    final snapshot = await _series.where('userId', isEqualTo: userId).get();

    for (final document in snapshot.docs) {
      final series = RecurringTransaction.fromMap(document.data(), document.id);
      await _reconcileSeries(series, today);
    }
  }

  Future<void> skipOccurrence({
    required String seriesId,
    required String occurrenceDate,
  }) async {
    await _series
        .doc(seriesId)
        .collection('skippedOccurrences')
        .doc(occurrenceDate)
        .set({'date': occurrenceDate});
  }

  Future<void> _reconcileSeries(
    RecurringTransaction series,
    DateTime today,
  ) async {
    final id = series.id;
    if (id == null || series.userId.isEmpty) return;

    final skippedSnapshot = await _series
        .doc(id)
        .collection('skippedOccurrences')
        .get();
    final skippedDates = skippedSnapshot.docs.map((doc) => doc.id).toSet();
    final start = _dateOnly(series.startDate);
    final end = series.endDate == null ? null : _dateOnly(series.endDate!);
    if (start.isAfter(today) || (end != null && end.isBefore(start))) return;

    var index = 0;
    var batch = _db.batch();
    var pendingWrites = 0;
    while (true) {
      final date = _occurrenceDate(series, index);
      final occurrenceDay = _dateOnly(date);
      if (occurrenceDay.isAfter(today) ||
          (end != null && occurrenceDay.isAfter(end))) {
        break;
      }

      final key = _dateKey(date);
      if (!skippedDates.contains(key)) {
        final collection = _db.collection(
          series.isExpense ? 'expenses' : 'incomes',
        );
        final transactionId = '${id}_$key';
        final transaction = collection.doc(transactionId);
        final existing = await transaction.get();
        if (!existing.exists) {
          final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          batch.set(transaction, {
            'userId': series.userId,
            'amount': series.amount,
            if (series.isExpense) 'category': series.category,
            if (!series.isExpense) 'source': series.category,
            'date': Timestamp.fromDate(date),
            'month': month,
            'description': series.description,
            if (series.isExpense) 'isImpulsive': series.isImpulsive,
            'recurrenceId': id,
            'recurrenceDate': key,
          });
          pendingWrites++;
          if (pendingWrites == 400) {
            await batch.commit();
            batch = _db.batch();
            pendingWrites = 0;
          }
        }
      }
      index++;
    }

    if (pendingWrites > 0) await batch.commit();
  }

  DateTime _occurrenceDate(RecurringTransaction series, int index) {
    final start = series.startDate;
    switch (series.frequency) {
      case RecurrenceFrequency.weekly:
        return start.add(Duration(days: 7 * index));
      case RecurrenceFrequency.monthly:
        final firstOfMonth = DateTime(start.year, start.month + index);
        final lastDay = DateTime(
          firstOfMonth.year,
          firstOfMonth.month + 1,
          0,
        ).day;
        final day = start.day > lastDay ? lastDay : start.day;
        return DateTime(
          firstOfMonth.year,
          firstOfMonth.month,
          day,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
          start.microsecond,
        );
      case RecurrenceFrequency.yearly:
        final year = start.year + index;
        final lastDay = DateTime(year, start.month + 1, 0).day;
        final day = start.day > lastDay ? lastDay : start.day;
        return DateTime(
          year,
          start.month,
          day,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
          start.microsecond,
        );
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
