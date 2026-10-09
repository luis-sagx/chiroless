import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/models/user_model.dart';

void main() {
  test('user serialization preserves streak data for reactive consumers', () {
    final user = AppUser(
      uid: 'u',
      name: 'Ana',
      email: '',
      level: 'Novato',
      createdAt: DateTime(2026),
    );
    expect(user.toMap()['currentStreak'], 0);
  });
}
