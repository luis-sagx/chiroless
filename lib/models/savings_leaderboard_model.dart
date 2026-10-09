class SavingsEntry {
  final String userId;
  final String alias;
  final double savingsPercent;
  const SavingsEntry({
    required this.userId,
    required this.alias,
    required this.savingsPercent,
  });
}

class SavingsParticipation {
  final bool enabled;
  final String alias;
  final List<String> publishedMonths;
  const SavingsParticipation({
    this.enabled = false,
    this.alias = '',
    this.publishedMonths = const [],
  });
}

class SavingsLeaderboardRules {
  static double? percentage(double income, double expense) {
    if (!income.isFinite || !expense.isFinite || income <= 0 || expense < 0) {
      return null;
    }
    final value = (income - expense) / income * 100;
    return value.isFinite ? double.parse(value.toStringAsFixed(2)) : null;
  }

  static List<SavingsEntry> ordered(Iterable<SavingsEntry> entries) {
    final result = entries
        .where((e) => e.savingsPercent.isFinite && e.savingsPercent <= 100)
        .toList();
    result.sort((a, b) {
      final score = b.savingsPercent.compareTo(a.savingsPercent);
      if (score != 0) return score;
      final alias = a.alias.toLowerCase().compareTo(b.alias.toLowerCase());
      return alias != 0 ? alias : a.userId.compareTo(b.userId);
    });
    return result;
  }

  static int rankOf(List<SavingsEntry> entries, String userId) {
    final index = entries.indexWhere((entry) => entry.userId == userId);
    if (index < 0) return 0;
    return entries.indexWhere(
          (entry) => entry.savingsPercent == entries[index].savingsPercent,
        ) +
        1;
  }

  static String monthKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
