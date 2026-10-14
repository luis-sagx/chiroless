class AppUser {
  final String uid;
  final String name;
  final String email;
  final String level;
  final int points;
  final int currentStreak;
  final String? lastTxDate;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.level,
    this.points = 0,
    this.currentStreak = 0,
    this.lastTxDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'level': level,
      'points': points,
      'currentStreak': currentStreak,
      'lastTxDate': lastTxDate,
      'createdAt': createdAt,
    };
  }
}
