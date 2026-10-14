import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../models/income_model.dart';

class UserService {
  final FirebaseFirestore _db;

  UserService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Convert legacy starting money once, without treating it as a new action.
  Future<void> migrateOpeningBalanceToIncome(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      if (data == null || data['openingBalanceMigrated'] == true) return;
      final value = data['openingBalanceAmount'];
      if (value == null || value == 0) return;
      if (value is! num || !value.isFinite || value < 0) {
        throw StateError('Importe heredado inválido');
      }
      final storedDate = data['openingBalanceDate'];
      final DateTime date;
      if (storedDate is Timestamp) {
        date = storedDate.toDate();
      } else if (storedDate is DateTime) {
        date = storedDate;
      } else {
        throw StateError('Fecha heredada inválida');
      }
      // Only read the owner profile: rules prohibit reading a missing income.
      // The profile marker and deterministic income commit together; concurrent
      // clients retry against the marker, even after an income is later deleted.
      transaction.set(
        _db.collection('incomes').doc('opening-balance-$uid'),
        Income(
          userId: uid,
          amount: value.toDouble(),
          source: 'Otros',
          description: 'Dinero inicial',
          date: date,
        ).toMap(),
      );
      transaction.update(userRef, {'openingBalanceMigrated': true});
    });
  }

  Future<void> createUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return AppUser(
          uid: uid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          level: data['level'] ?? 'Principiante',
          points: data['points'] ?? 0,
          currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
          lastTxDate: data['lastTxDate'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Stream<AppUser?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        return AppUser(
          uid: uid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          level: data['level'] ?? 'Principiante',
          points: data['points'] ?? 0,
          currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
          lastTxDate: data['lastTxDate'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        );
      }
      return null;
    });
  }
}
