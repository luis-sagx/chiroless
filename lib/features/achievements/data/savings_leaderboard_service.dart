import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/savings_leaderboard_model.dart';

class SavingsLeaderboardService {
  final FirebaseFirestore db;
  SavingsLeaderboardService({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      db.collection('users/$uid/leaderboard').doc('profile');
  DocumentReference<Map<String, dynamic>> _entry(String uid, String month) =>
      db.collection('leaderboardMonths/$month/entries').doc(uid);
  SavingsParticipation _participation(Map<String, dynamic>? data) =>
      SavingsParticipation(
        enabled: data?['enabled'] == true,
        alias: data?['alias'] as String? ?? '',
        publishedMonths: List<String>.from(
          data?['publishedMonths'] ?? const [],
        ),
      );
  Stream<SavingsParticipation> watchParticipation(String userId) =>
      _profile(userId).snapshots().map((s) => _participation(s.data()));
  Stream<List<SavingsEntry>> watchMonth(String month) => db
      .collection('leaderboardMonths/$month/entries')
      .snapshots()
      .map(
        (s) => SavingsLeaderboardRules.ordered(
          s.docs.map(
            (d) => SavingsEntry(
              userId: d.id,
              alias: d.data()['alias'] as String,
              savingsPercent: (d.data()['savingsPercent'] as num).toDouble(),
            ),
          ),
        ),
      );
  Stream<void> watchTransactions(
    String userId,
    String month, {
    required bool income,
  }) => db
      .collection(income ? 'incomes' : 'expenses')
      .where('userId', isEqualTo: userId)
      .where('month', isEqualTo: month)
      .snapshots()
      .map((_) {});
  Future<void> participate(String userId, String alias) async {
    final clean = alias.trim();
    if (clean.length < 2 ||
        clean.length > 24 ||
        clean.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('El alias debe tener entre 2 y 24 caracteres.');
    }
    await db.runTransaction((tx) async {
      final ref = _profile(userId);
      final existing = await tx.get(ref);
      tx.set(ref, {
        'enabled': true,
        'alias': clean,
        'publishedMonths': _participation(existing.data()).publishedMonths,
      });
    });
  }

  Future<void> withdraw(String userId) async {
    await db.runTransaction((tx) async {
      final ref = _profile(userId);
      final profile = _participation((await tx.get(ref)).data());
      for (final month in profile.publishedMonths) {
        tx.delete(_entry(userId, month));
      }
      tx.set(ref, {
        'enabled': false,
        'alias': profile.alias,
        'publishedMonths': <String>[],
      });
    });
  }

  Future<void> synchronizeMonth(
    String userId,
    String month, {
    bool Function()? isCurrent,
  }) async {
    if (isCurrent?.call() == false) return;
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
      throw ArgumentError('Mes inválido');
    }
    // Read private records on every serialized refresh, not stale UI totals.
    final records = await Future.wait(
      ['incomes', 'expenses'].map(
        (collection) => db
            .collection(collection)
            .where('userId', isEqualTo: userId)
            .where('month', isEqualTo: month)
            .get(),
      ),
    );
    double total(QuerySnapshot<Map<String, dynamic>> snapshot) =>
        snapshot.docs.fold(
          0.0,
          (total, doc) => total + (doc.data()['amount'] as num).toDouble(),
        );
    final percentage = SavingsLeaderboardRules.percentage(
      total(records[0]),
      total(records[1]),
    );
    await db.runTransaction((tx) async {
      final ref = _profile(userId);
      final profile = _participation((await tx.get(ref)).data());
      // The read participates in conflict detection with withdrawal on any device.
      if (!profile.enabled || isCurrent?.call() == false) return;
      final entry = _entry(userId, month);
      if (percentage == null) {
        tx.delete(entry);
        return;
      }
      tx.set(entry, {
        'alias': profile.alias,
        'savingsPercent': percentage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!profile.publishedMonths.contains(month)) {
        tx.update(ref, {
          'publishedMonths': [...profile.publishedMonths, month],
        });
      }
    });
  }
}
