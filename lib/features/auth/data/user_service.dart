import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

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
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          openingBalanceAmount:
              (data['openingBalanceAmount'] as num?)?.toDouble() ?? 0,
          openingBalanceDate: _openingBalanceDate(data['openingBalanceDate']),
          openingBalanceConfigured:
              data['openingBalanceConfigured'] as bool? ?? false,
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
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          openingBalanceAmount:
              (data['openingBalanceAmount'] as num?)?.toDouble() ?? 0,
          openingBalanceDate: _openingBalanceDate(data['openingBalanceDate']),
          openingBalanceConfigured:
              data['openingBalanceConfigured'] as bool? ?? false,
        );
      }
      return null;
    });
  }

  DateTime _openingBalanceDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
