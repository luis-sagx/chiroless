class AppUser {
  final String uid;
  final String name;
  final String email;
  final String level;
  final int points;
  final DateTime createdAt;
  final double openingBalanceAmount;
  final DateTime openingBalanceDate;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.level,
    this.points = 0,
    required this.createdAt,
    this.openingBalanceAmount = 0,
    DateTime? openingBalanceDate,
  }) : openingBalanceDate = _dateOnly(openingBalanceDate ?? DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'level': level,
      'points': points,
      'createdAt': createdAt,
      'openingBalanceAmount': openingBalanceAmount,
      'openingBalanceDate': openingBalanceDate,
    };
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
